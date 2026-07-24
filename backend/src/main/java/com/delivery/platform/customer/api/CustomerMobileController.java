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

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/customer")
@PreAuthorize("hasRole('CUSTOMER')")
public class CustomerMobileController {
    private final JdbcClient db;
    public CustomerMobileController(JdbcClient db){this.db=db;}

    public record Profile(UUID id,String firstName,String lastName,String email){}
    public record ProfileRequest(@NotBlank @Size(max=100) String firstName,@NotBlank @Size(max=100) String lastName){}
    public record Address(UUID id,String label,String recipientName,String phone,String addressLine,String district,String province,String department,String countryCode,String postalCode,BigDecimal latitude,BigDecimal longitude,String reference,boolean isDefault){}
    public record AddressRequest(@NotBlank @Size(max=80) String label,@NotBlank @Size(max=160) String recipientName,@NotBlank @Size(max=40) String phone,@NotBlank @Size(max=255) String addressLine,@Size(max=100) String district,@Size(max=100) String province,@Size(max=100) String department,@Pattern(regexp="[A-Z]{2}") String countryCode,@Size(max=20) String postalCode,@DecimalMin("-90") @DecimalMax("90") BigDecimal latitude,@DecimalMin("-180") @DecimalMax("180") BigDecimal longitude,@Size(max=255) String reference,boolean isDefault){}
    public record Merchant(UUID id,String code,String name,String description,String merchantType,String currency,UUID branchId,String branchName,String district,BigDecimal minimumOrderAmount,Integer preparationTimeMinutes){}

    @GetMapping("/me") Profile me(@AuthenticationPrincipal IdentityPrincipal p){return db.sql("select id,first_name,last_name,email from users where id=:id and tenant_id=:tenant").param("id",p.userId()).param("tenant",p.tenantId()).query(Profile.class).single();}
    @PutMapping("/me") @Transactional Profile update(@AuthenticationPrincipal IdentityPrincipal p,@Valid @RequestBody ProfileRequest q){db.sql("update users set first_name=:first,last_name=:last,updated_at=now() where id=:id and tenant_id=:tenant").param("first",q.firstName().trim()).param("last",q.lastName().trim()).param("id",p.userId()).param("tenant",p.tenantId()).update();return me(p);}

    @GetMapping("/addresses") List<Address> addresses(@AuthenticationPrincipal IdentityPrincipal p){return db.sql("select id,label,recipient_name,phone,address_line,district,province,department,country_code,postal_code,latitude,longitude,reference,is_default from delivery_addresses where tenant_id=:tenant and customer_id=:user and active order by is_default desc,created_at desc").param("tenant",p.tenantId()).param("user",p.userId()).query(Address.class).list();}
    @PostMapping("/addresses") @ResponseStatus(HttpStatus.CREATED) @Transactional Address create(@AuthenticationPrincipal IdentityPrincipal p,@Valid @RequestBody AddressRequest q){UUID id=UUID.randomUUID();if(q.isDefault())clearDefault(p);db.sql("insert into delivery_addresses(id,tenant_id,customer_id,label,recipient_name,phone,address_line,district,province,department,country_code,postal_code,latitude,longitude,reference,is_default) values(:id,:tenant,:user,:label,:recipient,:phone,:line,:district,:province,:department,:country,:postal,:lat,:lng,:reference,:default)").param("id",id).param("tenant",p.tenantId()).param("user",p.userId()).param("label",q.label()).param("recipient",q.recipientName()).param("phone",q.phone()).param("line",q.addressLine()).param("district",q.district()).param("province",q.province()).param("department",q.department()).param("country",q.countryCode()==null?"PE":q.countryCode()).param("postal",q.postalCode()).param("lat",q.latitude()).param("lng",q.longitude()).param("reference",q.reference()).param("default",q.isDefault()||addresses(p).isEmpty()).update();return address(p,id);}
    @PutMapping("/addresses/{id}") @Transactional Address updateAddress(@AuthenticationPrincipal IdentityPrincipal p,@PathVariable UUID id,@Valid @RequestBody AddressRequest q){ownedAddress(p,id);if(q.isDefault())clearDefault(p);db.sql("update delivery_addresses set label=:label,recipient_name=:recipient,phone=:phone,address_line=:line,district=:district,province=:province,department=:department,country_code=:country,postal_code=:postal,latitude=:lat,longitude=:lng,reference=:reference,is_default=:default,updated_at=now() where id=:id and tenant_id=:tenant and customer_id=:user").param("label",q.label()).param("recipient",q.recipientName()).param("phone",q.phone()).param("line",q.addressLine()).param("district",q.district()).param("province",q.province()).param("department",q.department()).param("country",q.countryCode()==null?"PE":q.countryCode()).param("postal",q.postalCode()).param("lat",q.latitude()).param("lng",q.longitude()).param("reference",q.reference()).param("default",q.isDefault()).param("id",id).param("tenant",p.tenantId()).param("user",p.userId()).update();return address(p,id);}
    @DeleteMapping("/addresses/{id}") @ResponseStatus(HttpStatus.NO_CONTENT) @Transactional void delete(@AuthenticationPrincipal IdentityPrincipal p,@PathVariable UUID id){ownedAddress(p,id);db.sql("update delivery_addresses set active=false,is_default=false,updated_at=now() where id=:id").param("id",id).update();}
    @PutMapping("/addresses/{id}/default") @Transactional Address makeDefault(@AuthenticationPrincipal IdentityPrincipal p,@PathVariable UUID id){ownedAddress(p,id);clearDefault(p);db.sql("update delivery_addresses set is_default=true,updated_at=now() where id=:id").param("id",id).update();return address(p,id);}

    @GetMapping("/merchants") List<Merchant> merchants(@AuthenticationPrincipal IdentityPrincipal p,@RequestParam(defaultValue="") String search){return db.sql("select m.id,m.code,m.name,m.description,m.merchant_type,m.default_currency currency,b.id branch_id,b.name branch_name,b.district,b.minimum_order_amount,b.preparation_time_minutes from merchants m join lateral(select * from branches where tenant_id=m.tenant_id and merchant_id=m.id and status='ACTIVE' order by created_at limit 1)b on true where m.tenant_id=:tenant and m.status='ACTIVE' and (:search='' or lower(m.name||' '||coalesce(m.description,'')) like lower('%'||:search||'%')) order by m.name").param("tenant",p.tenantId()).param("search",search).query(Merchant.class).list();}

    private Address address(IdentityPrincipal p,UUID id){return db.sql("select id,label,recipient_name,phone,address_line,district,province,department,country_code,postal_code,latitude,longitude,reference,is_default from delivery_addresses where id=:id and tenant_id=:tenant and customer_id=:user and active").param("id",id).param("tenant",p.tenantId()).param("user",p.userId()).query(Address.class).optional().orElseThrow(()->new ApiException(HttpStatus.NOT_FOUND,"ADDRESS_NOT_FOUND","Dirección no encontrada"));}
    private void ownedAddress(IdentityPrincipal p,UUID id){address(p,id);}
    private void clearDefault(IdentityPrincipal p){db.sql("update delivery_addresses set is_default=false where tenant_id=:tenant and customer_id=:user and active").param("tenant",p.tenantId()).param("user",p.userId()).update();}
}
