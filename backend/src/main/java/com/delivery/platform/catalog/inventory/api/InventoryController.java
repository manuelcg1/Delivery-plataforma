package com.delivery.platform.catalog.inventory.api;

import com.delivery.platform.catalog.common.CatalogSupport;
import com.delivery.platform.common.ApiException;
import com.delivery.platform.common.PageResponse;
import com.delivery.platform.identity.security.IdentityPrincipal;
import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/inventory")
public class InventoryController {
    private final JdbcClient db;
    private final CatalogSupport support;

    public InventoryController(JdbcClient db, CatalogSupport support) {
        this.db = db;
        this.support = support;
    }

    public record Stock(UUID productId, String productName, String sku, BigDecimal quantity,
                        BigDecimal lowStockThreshold, boolean lowStock) {}
    public record Target(UUID productId, String productName, String sku, BigDecimal quantity,
                         boolean trackInventory) {}
    public record Adjustment(UUID branchId, UUID productId, UUID variantId,
                             @NotNull @DecimalMin(value="0", inclusive=false) BigDecimal quantity,
                             @NotBlank @Pattern(regexp="INCREASE|DECREASE|ADJUSTMENT|INITIAL") String movementType,
                             String notes) {}
    public record Movement(UUID id, UUID branchId, UUID productId, UUID variantId, String productName,
                           String movementType, BigDecimal quantity, BigDecimal previousQuantity,
                           BigDecimal resultingQuantity, Instant createdAt) {}

                private static final String PRODUCT_SCOPE = """
                                                and (:tenantAdmin or exists(select 1 from merchant_memberships mm
                                                        where mm.tenant_id=p.tenant_id and mm.merchant_id=p.merchant_id
                                                                and mm.user_id=:user and mm.active))
                                                """;

    @GetMapping
    @PreAuthorize("hasAuthority('CATALOG_INVENTORY_VIEW')")
    PageResponse<Stock> stock(@AuthenticationPrincipal IdentityPrincipal principal,
                              @RequestParam(required=false) UUID merchantId,
                              @RequestParam(defaultValue="") String search,
                              @RequestParam(defaultValue="0") int page,
                              @RequestParam(defaultValue="20") int size) {
        int safeSize=Math.min(Math.max(size,1),100), current=Math.max(page,0);
        if (merchantId != null) support.merchant(principal, merchantId);
        String where=" from products p where p.tenant_id=:tenant and p.track_inventory and p.status<>'ARCHIVED' " +
                "and (cast(:merchant as uuid) is null or p.merchant_id=:merchant) " + PRODUCT_SCOPE +
                "and (:search='' or lower(p.name||' '||coalesce(p.sku,'')) like lower('%'||:search||'%'))";
        boolean tenantAdmin=tenantAdmin(principal);
        var rows=db.sql("select p.id,p.name,p.sku,coalesce(p.stock_quantity,0) quantity,p.low_stock_threshold"+where+" order by p.name limit :size offset :offset")
                .param("tenant",principal.tenantId()).param("merchant",merchantId).param("search",search)
                .param("tenantAdmin",tenantAdmin).param("user",principal.userId())
                .param("size",safeSize).param("offset",current*safeSize)
                .query((result,row)->{BigDecimal quantity=result.getBigDecimal("quantity"), threshold=result.getBigDecimal("low_stock_threshold");return new Stock(result.getObject("id",UUID.class),result.getString("name"),result.getString("sku"),quantity,threshold,threshold!=null&&quantity.compareTo(threshold)<=0);}).list();
        long total=db.sql("select count(*)"+where).param("tenant",principal.tenantId()).param("merchant",merchantId).param("search",search)
                .param("tenantAdmin",tenantAdmin).param("user",principal.userId()).query(Long.class).single();
        return PageResponse.of(rows,current,safeSize,total);
    }

    @GetMapping("/targets")
    @PreAuthorize("hasAuthority('CATALOG_INVENTORY_ADJUST')")
    List<Target> targets(@AuthenticationPrincipal IdentityPrincipal principal) {
        boolean tenantAdmin=tenantAdmin(principal);
        return db.sql("select p.id,p.name,p.sku,coalesce(p.stock_quantity,0) quantity,p.track_inventory from products p where p.tenant_id=:tenant and p.status<>'ARCHIVED' " + PRODUCT_SCOPE + " order by p.name")
                .param("tenant",principal.tenantId())
                .param("tenantAdmin",tenantAdmin).param("user",principal.userId())
                .query((result,row)->new Target(result.getObject("id",UUID.class),result.getString("name"),result.getString("sku"),result.getBigDecimal("quantity"),result.getBoolean("track_inventory"))).list();
    }

    @PostMapping("/adjustments")
    @Transactional
    @PreAuthorize("hasAuthority('CATALOG_INVENTORY_ADJUST')")
    Movement adjust(@AuthenticationPrincipal IdentityPrincipal principal, @Valid @RequestBody Adjustment request) {
        if ((request.productId()==null)==(request.variantId()==null)) throw new ApiException(HttpStatus.BAD_REQUEST,"INVALID_INVENTORY_ADJUSTMENT","Indica exactamente un producto o una variante");
        if(request.branchId()!=null) support.branch(principal,request.branchId());
        String table=request.productId()!=null?"products":"product_variants";
        UUID target=request.productId()!=null?request.productId():request.variantId();
        String notFound=request.productId()!=null?"PRODUCT_NOT_FOUND":"VARIANT_NOT_FOUND";
        UUID productId=request.productId();
        if(productId==null){
            productId=db.sql("select product_id from product_variants where id=:id and tenant_id=:tenant")
                    .param("id",target).param("tenant",principal.tenantId()).query(UUID.class).optional()
                    .orElseThrow(()->new ApiException(HttpStatus.NOT_FOUND,notFound,"Elemento de inventario no encontrado"));
        }
        support.product(principal,productId);
        if(request.branchId()!=null){
            int sameMerchant=db.sql("select count(*) from branches b join products p on p.merchant_id=b.merchant_id and p.tenant_id=b.tenant_id where b.id=:branch and p.id=:product and b.tenant_id=:tenant")
                    .param("branch",request.branchId()).param("product",productId).param("tenant",principal.tenantId()).query(Integer.class).single();
            if(sameMerchant==0)throw new ApiException(HttpStatus.BAD_REQUEST,"INVALID_BRANCH_PRODUCT","Producto y sucursal deben pertenecer al mismo comercio");
        }
        BigDecimal current=db.sql("select coalesce(stock_quantity,0) from "+table+" where id=:id and tenant_id=:tenant for update")
                .param("id",target).param("tenant",principal.tenantId()).query(BigDecimal.class).optional()
                .orElseThrow(()->new ApiException(HttpStatus.NOT_FOUND,notFound,"Elemento de inventario no encontrado"));
        BigDecimal result=switch(request.movementType()){case "INCREASE","INITIAL"->current.add(request.quantity());case "DECREASE"->current.subtract(request.quantity());default->request.quantity();};
        if(result.signum()<0) throw new ApiException(HttpStatus.CONFLICT,"INSUFFICIENT_STOCK","El ajuste dejaría el stock en negativo");
        db.sql("update "+table+" set stock_quantity=:quantity,track_inventory=true,updated_at=now() where id=:id and tenant_id=:tenant").param("quantity",result).param("id",target).param("tenant",principal.tenantId()).update();
        UUID id=UUID.randomUUID();
        db.sql("insert into inventory_movements(id,tenant_id,branch_id,product_id,variant_id,movement_type,quantity,previous_quantity,resulting_quantity,notes,created_by) values(:id,:tenant,:branch,:product,:variant,:type,:quantity,:previous,:result,:notes,:user)")
                .param("id",id).param("tenant",principal.tenantId()).param("branch",request.branchId()).param("product",request.productId()).param("variant",request.variantId()).param("type",request.movementType()).param("quantity",request.quantity()).param("previous",current).param("result",result).param("notes",request.notes()).param("user",principal.userId()).update();
        support.audit(principal,"INVENTORY_ADJUSTED","INVENTORY_MOVEMENT",id);
        String productName=request.productId()==null?null:db.sql("select name from products where id=:id and tenant_id=:tenant").param("id",request.productId()).param("tenant",principal.tenantId()).query(String.class).single();
        return new Movement(id,request.branchId(),request.productId(),request.variantId(),productName,request.movementType(),request.quantity(),current,result,Instant.now());
    }

    @GetMapping("/movements")
    @PreAuthorize("hasAuthority('CATALOG_INVENTORY_VIEW')")
    PageResponse<Movement> movements(@AuthenticationPrincipal IdentityPrincipal principal,
                                     @RequestParam(required=false) UUID productId,
                                     @RequestParam(required=false) String movementType,
                                     @RequestParam(defaultValue="0") int page,
                                     @RequestParam(defaultValue="20") int size) {
        int safeSize=Math.min(Math.max(size,1),100), current=Math.max(page,0);
        boolean tenantAdmin=tenantAdmin(principal);
        String where=" from inventory_movements im left join products p on p.id=coalesce(im.product_id,(select pv.product_id from product_variants pv where pv.id=im.variant_id and pv.tenant_id=im.tenant_id)) and p.tenant_id=im.tenant_id where im.tenant_id=:tenant and (cast(:product as uuid) is null or im.product_id=:product or exists(select 1 from product_variants pv where pv.id=im.variant_id and pv.product_id=:product and pv.tenant_id=im.tenant_id)) " + PRODUCT_SCOPE + " and (cast(:type as varchar) is null or im.movement_type=:type)";
        var rows=db.sql("select im.id,im.branch_id,im.product_id,im.variant_id,p.name product_name,im.movement_type,im.quantity,im.previous_quantity,im.resulting_quantity,im.created_at"+where+" order by im.created_at desc limit :size offset :offset")
                .param("tenant",principal.tenantId()).param("product",productId).param("type",movementType).param("tenantAdmin",tenantAdmin).param("user",principal.userId()).param("size",safeSize).param("offset",current*safeSize)
                .query((result,row)->new Movement(result.getObject("id",UUID.class),result.getObject("branch_id",UUID.class),result.getObject("product_id",UUID.class),result.getObject("variant_id",UUID.class),result.getString("product_name"),result.getString("movement_type"),result.getBigDecimal("quantity"),result.getBigDecimal("previous_quantity"),result.getBigDecimal("resulting_quantity"),result.getTimestamp("created_at").toInstant())).list();
                long total=db.sql("select count(*)"+where).param("tenant",principal.tenantId()).param("product",productId).param("type",movementType).param("tenantAdmin",tenantAdmin).param("user",principal.userId()).query(Long.class).single();
        return PageResponse.of(rows,current,safeSize,total);
    }

        private boolean tenantAdmin(IdentityPrincipal principal) {
                return principal.roles().contains("TENANT_ADMIN") || principal.roles().contains("PLATFORM_ADMIN");
        }
}
