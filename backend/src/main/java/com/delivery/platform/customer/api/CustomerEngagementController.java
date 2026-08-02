package com.delivery.platform.customer.api;

import com.delivery.platform.common.ApiException;
import com.delivery.platform.identity.security.IdentityPrincipal;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/customer")
@PreAuthorize("hasRole('CUSTOMER')")
public class CustomerEngagementController {
    private final JdbcClient db;
    public CustomerEngagementController(JdbcClient db){this.db=db;}
    public record Favorite(UUID id,UUID merchantId,UUID productId,String name,String description,Instant createdAt){}
    public record FavoriteRequest(UUID merchantId,UUID productId){}
    public record Rating(UUID id,UUID orderId,int score,String comment,Instant createdAt){}
    public record RatingRequest(@Min(1) @Max(5) int score,@Size(max=500) String comment){}
    public record Device(UUID id,String platform,boolean active){}
    public record DeviceRequest(@NotBlank @Pattern(regexp="ANDROID|IOS") String platform,@NotBlank @Size(max=500) String token){}

    @GetMapping("/favorites") List<Favorite> favorites(@AuthenticationPrincipal IdentityPrincipal p){return db.sql("select f.id,f.merchant_id,f.product_id,coalesce(m.name,pr.name) name,coalesce(m.description,pr.description) description,f.created_at from customer_favorites f left join merchants m on m.id=f.merchant_id and m.tenant_id=f.tenant_id left join products pr on pr.id=f.product_id and pr.tenant_id=f.tenant_id where f.tenant_id=:tenant and f.customer_id=:user order by f.created_at desc").param("tenant",p.tenantId()).param("user",p.userId()).query(Favorite.class).list();}
    @PostMapping("/favorites") @ResponseStatus(HttpStatus.CREATED) @Transactional Favorite addFavorite(@AuthenticationPrincipal IdentityPrincipal p,@Valid @RequestBody FavoriteRequest q){if((q.merchantId()==null)==(q.productId()==null))throw error(HttpStatus.BAD_REQUEST,"FAVORITE_TARGET_INVALID","Indica un comercio o un producto");String table=q.merchantId()!=null?"merchants":"products";UUID target=q.merchantId()!=null?q.merchantId():q.productId();int owned=db.sql("select count(*) from "+table+" where id=:id and tenant_id=:tenant").param("id",target).param("tenant",p.tenantId()).query(Integer.class).single();if(owned==0)throw error(HttpStatus.NOT_FOUND,"FAVORITE_TARGET_NOT_FOUND","Elemento no encontrado");UUID id=UUID.randomUUID();db.sql("insert into customer_favorites(id,tenant_id,customer_id,merchant_id,product_id) values(:id,:tenant,:user,:merchant,:product) on conflict do nothing").param("id",id).param("tenant",p.tenantId()).param("user",p.userId()).param("merchant",q.merchantId()).param("product",q.productId()).update();return favorites(p).stream().filter(x->target.equals(q.merchantId()!=null?x.merchantId():x.productId())).findFirst().orElseThrow();}
    @DeleteMapping("/favorites/{id}") @ResponseStatus(HttpStatus.NO_CONTENT) @Transactional void removeFavorite(@AuthenticationPrincipal IdentityPrincipal p,@PathVariable UUID id){int removed=db.sql("delete from customer_favorites where id=:id and tenant_id=:tenant and customer_id=:user").param("id",id).param("tenant",p.tenantId()).param("user",p.userId()).update();if(removed==0)throw error(HttpStatus.NOT_FOUND,"FAVORITE_NOT_FOUND","Favorito no encontrado");}

    @GetMapping("/orders/{orderId}/rating") Rating rating(@AuthenticationPrincipal IdentityPrincipal p,@PathVariable UUID orderId){ownedOrder(p,orderId,false);return db.sql("select id,order_id,score,comment,created_at from order_ratings where tenant_id=:tenant and customer_id=:user and order_id=:order").param("tenant",p.tenantId()).param("user",p.userId()).param("order",orderId).query(Rating.class).optional().orElseThrow(()->error(HttpStatus.NOT_FOUND,"RATING_NOT_FOUND","Calificación no encontrada"));}
    @PostMapping("/orders/{orderId}/rating") @ResponseStatus(HttpStatus.CREATED) @Transactional Rating rate(@AuthenticationPrincipal IdentityPrincipal p,@PathVariable UUID orderId,@Valid @RequestBody RatingRequest q){ownedOrder(p,orderId,true);int inserted=db.sql("insert into order_ratings(tenant_id,order_id,customer_id,score,comment) values(:tenant,:order,:user,:score,:comment) on conflict(order_id,customer_id) do nothing").param("tenant",p.tenantId()).param("order",orderId).param("user",p.userId()).param("score",q.score()).param("comment",q.comment()).update();if(inserted==0)throw error(HttpStatus.CONFLICT,"RATING_ALREADY_SUBMITTED","Este pedido ya fue calificado");return rating(p,orderId);}

    @PostMapping("/devices") @ResponseStatus(HttpStatus.CREATED) @Transactional Device device(@AuthenticationPrincipal IdentityPrincipal p,@Valid @RequestBody DeviceRequest q){UUID id=UUID.randomUUID();db.sql("insert into customer_devices(id,tenant_id,user_id,platform,token) values(:id,:tenant,:user,:platform,:token) on conflict(user_id,token) do update set active=true,platform=excluded.platform,updated_at=now()").param("id",id).param("tenant",p.tenantId()).param("user",p.userId()).param("platform",q.platform()).param("token",q.token()).update();return db.sql("select id,platform,active from customer_devices where tenant_id=:tenant and user_id=:user and token=:token").param("tenant",p.tenantId()).param("user",p.userId()).param("token",q.token()).query(Device.class).single();}
    @DeleteMapping("/devices/{id}") @ResponseStatus(HttpStatus.NO_CONTENT) @Transactional void disableDevice(@AuthenticationPrincipal IdentityPrincipal p,@PathVariable UUID id){db.sql("update customer_devices set active=false,updated_at=now() where id=:id and tenant_id=:tenant and user_id=:user").param("id",id).param("tenant",p.tenantId()).param("user",p.userId()).update();}

    private void ownedOrder(IdentityPrincipal p,UUID orderId,boolean delivered){String status=delivered?" and status='DELIVERED'":"";int count=db.sql("select count(*) from orders where id=:id and tenant_id=:tenant and customer_id=:user"+status).param("id",orderId).param("tenant",p.tenantId()).param("user",p.userId()).query(Integer.class).single();if(count==0)throw error(delivered?HttpStatus.CONFLICT:HttpStatus.NOT_FOUND,delivered?"ORDER_NOT_DELIVERED":"ORDER_NOT_FOUND",delivered?"Solo puedes calificar pedidos entregados":"Pedido no encontrado");}
    private ApiException error(HttpStatus status,String code,String message){return new ApiException(status,code,message);}
}
