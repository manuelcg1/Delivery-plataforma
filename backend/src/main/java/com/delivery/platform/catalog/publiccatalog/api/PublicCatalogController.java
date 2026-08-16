package com.delivery.platform.catalog.publiccatalog.api;

import com.delivery.platform.catalog.cache.CatalogCache;
import com.delivery.platform.catalog.media.infrastructure.MinioCatalogStorage;
import com.delivery.platform.common.ApiException;
import com.fasterxml.jackson.core.type.TypeReference;
import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/public/catalog")
public class PublicCatalogController {
    private final JdbcClient db;
    private final CatalogCache cache;
    private final MinioCatalogStorage storage;
    public PublicCatalogController(JdbcClient db, CatalogCache cache, MinioCatalogStorage storage) { this.db = db; this.cache = cache; this.storage = storage; }

    public record Merchant(UUID id,String code,String name,String description,String merchantType,String logoObjectKey,String bannerObjectKey,String currency) { }
    public record Branch(UUID id,String code,String name,String addressLine,String district,String status) { }
    public record Category(UUID id,UUID parentId,String code,String name,String description,int sortOrder) { }
    public record Product(UUID id,UUID categoryId,String slug,String name,String description,String productType,BigDecimal price,String currency,boolean featured,List<Variant> variants,List<Image> images,List<OptionGroup> optionGroups) { }
    public record Variant(UUID id,String name,BigDecimal price) { }
    public record Image(UUID id,String url,String altText,int sortOrder,boolean primaryImage) { }
    public record OptionGroup(UUID id,String name,String selectionType,boolean required,int minimumSelections,Integer maximumSelections,List<OptionItem> items) { }
    public record OptionItem(UUID id,String name,BigDecimal priceAdjustment) { }

    @GetMapping("/merchants/{code}")
    public Merchant merchant(@PathVariable String code) {
        UUID tenant = tenantByMerchant(code);
        return cache.getOrLoad(tenant, "merchant:" + code, new TypeReference<>() {}, () ->
            db.sql("select id,code,name,description,merchant_type,logo_object_key,banner_object_key,default_currency from merchants where tenant_id=:t and code=:c and status='ACTIVE'")
              .param("t", tenant).param("c", code).query(Merchant.class).single());
    }

    @GetMapping("/merchants/{code}/branches")
    public List<Branch> branches(@PathVariable String code) {
        UUID tenant = tenantByMerchant(code);
        return cache.getOrLoad(tenant, "merchant:" + code + ":branches", new TypeReference<>() {}, () ->
            db.sql("select b.id,b.code,b.name,b.address_line,b.district,b.status from branches b join merchants m on m.id=b.merchant_id where m.tenant_id=:t and m.code=:c and m.status='ACTIVE' and b.status='ACTIVE' order by b.name")
              .param("t", tenant).param("c", code).query(Branch.class).list());
    }

    @GetMapping("/branches/{branchId}/categories")
    public List<Category> categories(@PathVariable UUID branchId) {
        UUID tenant = tenantByBranch(branchId);
        return cache.getOrLoad(tenant, "branch:" + branchId + ":categories", new TypeReference<>() {}, () ->
            db.sql("select c.id,c.parent_id,c.code,c.name,c.description,c.sort_order from categories c join branches b on b.merchant_id=c.merchant_id join merchants m on m.id=b.merchant_id where b.tenant_id=:t and b.id=:b and b.status='ACTIVE' and m.status='ACTIVE' and c.active order by c.sort_order,c.name")
              .param("t", tenant).param("b", branchId).query(Category.class).list());
    }

    @GetMapping("/branches/{branchId}/products")
    public List<Product> products(@PathVariable UUID branchId) {
        UUID tenant = tenantByBranch(branchId);
        return cache.getOrLoad(tenant, "branch:" + branchId + ":products", new TypeReference<>() {}, () ->
            db.sql("select p.id,p.category_id,p.slug,p.name,p.description,p.product_type,coalesce(bp.override_price,pli.price,p.base_price) price,p.currency,p.featured from products p join branches b on b.merchant_id=p.merchant_id join merchants m on m.id=p.merchant_id left join branch_products bp on bp.branch_id=b.id and bp.product_id=p.id left join lateral (select i.price from price_list_items i join price_lists l on l.id=i.price_list_id where i.product_id=p.id and l.merchant_id=p.merchant_id and l.active and (l.valid_from is null or l.valid_from<=now()) and (l.valid_to is null or l.valid_to>now()) order by l.created_at desc limit 1) pli on true where b.tenant_id=:t and b.id=:b and b.status='ACTIVE' and m.status='ACTIVE' and p.status='PUBLISHED' and p.available and coalesce(bp.available,true) order by p.sort_order,p.name")
              .param("t", tenant).param("b", branchId).query((rs,n) -> product(rs, tenant)).list());
    }

    @GetMapping("/products/{id}")
    public Product product(@PathVariable UUID id) {
        UUID tenant = db.sql("select tenant_id from products where id=:i and status='PUBLISHED' and available")
                .param("i", id).query(UUID.class).optional().orElseThrow(this::productMissing);
        return cache.getOrLoad(tenant, "product:" + id, new TypeReference<>() {}, () ->
            db.sql("select p.id,p.category_id,p.slug,p.name,p.description,p.product_type,p.base_price price,p.currency,p.featured from products p join merchants m on m.id=p.merchant_id where p.tenant_id=:t and p.id=:i and p.status='PUBLISHED' and p.available and m.status='ACTIVE'")
              .param("t", tenant).param("i", id).query((rs,n) -> product(rs, tenant)).optional().orElseThrow(this::productMissing));
    }

    private UUID tenantByMerchant(String code) {
        return db.sql("select tenant_id from merchants where code=:c and status='ACTIVE' order by created_at limit 1")
                .param("c", code).query(UUID.class).optional().orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND,"MERCHANT_NOT_FOUND","Comercio no encontrado"));
    }
    private UUID tenantByBranch(UUID id) {
        return db.sql("select tenant_id from branches where id=:i and status='ACTIVE'").param("i", id).query(UUID.class)
                .optional().orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND,"BRANCH_NOT_FOUND","Sucursal no encontrada"));
    }
    private Product product(java.sql.ResultSet rs, UUID tenant) throws java.sql.SQLException {
        UUID id = rs.getObject("id", UUID.class);
        List<Variant> variants = db.sql("select id,name,price from product_variants where tenant_id=:t and product_id=:p and active and available order by sort_order")
                .param("t", tenant).param("p", id).query(Variant.class).list();
        List<Image> images = db.sql("select id,object_key,alt_text,sort_order,primary_image from product_images where tenant_id=:t and product_id=:p order by primary_image desc,sort_order,created_at")
                .param("t", tenant).param("p", id).query((imageRs,n) -> new Image(
                        imageRs.getObject("id",UUID.class), storage.signedUrl(imageRs.getString("object_key")),
                        imageRs.getString("alt_text"), imageRs.getInt("sort_order"), imageRs.getBoolean("primary_image"))).list();
        List<OptionGroup> optionGroups = db.sql("select g.* from option_groups g join product_option_groups pg on pg.option_group_id=g.id where g.tenant_id=:t and pg.product_id=:p and g.active order by pg.sort_order,g.name")
                .param("t",tenant).param("p",id).query((groupRs,n) -> new OptionGroup(
                        groupRs.getObject("id",UUID.class),groupRs.getString("name"),groupRs.getString("selection_type"),groupRs.getBoolean("required"),groupRs.getInt("minimum_selections"),(Integer)groupRs.getObject("maximum_selections"),
                        db.sql("select id,name,price_adjustment from option_items where tenant_id=:t and option_group_id=:g and active and available order by sort_order,name")
                                .param("t",tenant).param("g",groupRs.getObject("id",UUID.class)).query(OptionItem.class).list())).list();
        return new Product(id,rs.getObject("category_id",UUID.class),rs.getString("slug"),rs.getString("name"),rs.getString("description"),rs.getString("product_type"),rs.getBigDecimal("price"),rs.getString("currency"),rs.getBoolean("featured"),variants,images,optionGroups);
    }
    private ApiException productMissing() { return new ApiException(HttpStatus.NOT_FOUND,"PRODUCT_NOT_FOUND","Producto no encontrado"); }
}
