package com.delivery.platform.catalog.merchant.api;

import com.delivery.platform.catalog.common.CatalogSupport;
import com.delivery.platform.common.ApiException;
import com.delivery.platform.identity.security.IdentityPrincipal;
import com.delivery.platform.merchant.application.MerchantAccountProvisioner;
import org.junit.jupiter.api.*;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import java.util.*;
import static org.assertj.core.api.Assertions.*;
import static org.mockito.Mockito.*;

class MerchantUpdateTest {
 JdbcClient db; CatalogSupport support; MerchantController controller;
 UUID tenant=UUID.randomUUID(),id=UUID.randomUUID();
 IdentityPrincipal actor=new IdentityPrincipal(UUID.randomUUID(),tenant,"test",Set.of("TENANT_ADMIN"),Set.of());
 @BeforeEach void setup(){
  db=JdbcClient.create(new DriverManagerDataSource("jdbc:h2:mem:"+UUID.randomUUID()+";MODE=PostgreSQL;DB_CLOSE_DELAY=-1","sa",""));
  db.sql("create table merchants(id uuid primary key,tenant_id uuid,code varchar unique,name varchar,legal_name varchar,description varchar,merchant_type varchar,email varchar,phone varchar,status varchar,default_currency varchar,timezone varchar,logo_object_key varchar,banner_object_key varchar,updated_at timestamp)").update();
  db.sql("insert into merchants(id,tenant_id,code,name,status,logo_object_key,banner_object_key) values(?,?,'old','Old','ACTIVE','logo-key','banner-key')").params(id,tenant).update();
  support=mock(CatalogSupport.class);
  when(support.conflict(anyString(),anyString())).thenAnswer(i->new ApiException(HttpStatus.CONFLICT,i.getArgument(0),i.getArgument(1)));
  controller=new MerchantController(db,support,mock(MerchantAccountProvisioner.class));
 }
 MerchantController.Save request(String code,String timezone){return new MerchantController.Save(code,"Nuevo","Legal","Descripción","PHARMACY","contact@example.test","999111222","PEN",timezone,null);}
 @Test void updatesAllFieldsPreservingIdentityStateAndMedia(){
  var result=controller.update(actor,id,request("new-code","America/Lima"));
  assertThat(result.id()).isEqualTo(id);assertThat(result.code()).isEqualTo("new-code");assertThat(result.name()).isEqualTo("Nuevo");
  assertThat(result.legalName()).isEqualTo("Legal");assertThat(result.description()).isEqualTo("Descripción");assertThat(result.merchantType()).isEqualTo("PHARMACY");
  assertThat(result.email()).isEqualTo("contact@example.test");assertThat(result.phone()).isEqualTo("999111222");assertThat(result.defaultCurrency()).isEqualTo("PEN");assertThat(result.timezone()).isEqualTo("America/Lima");
  assertThat(result.status()).isEqualTo("ACTIVE");assertThat(result.logoObjectKey()).isEqualTo("logo-key");assertThat(result.bannerObjectKey()).isEqualTo("banner-key");
  verify(support).audit(actor,"MERCHANT_UPDATED","MERCHANT",id);
 }
 @Test void duplicateCodeIsConflictAndDoesNotOverwrite(){
  db.sql("insert into merchants(id,tenant_id,code,name) values(?,?,'taken','Other')").params(UUID.randomUUID(),tenant).update();
  assertThatThrownBy(()->controller.update(actor,id,request("taken","America/Lima"))).isInstanceOfSatisfying(ApiException.class,e->assertThat(e.code).isEqualTo("DUPLICATE_CODE"));
  assertThat(db.sql("select name from merchants where id=?").param(id).query(String.class).single()).isEqualTo("Old");
 }
 @Test void invalidTimezoneRejectedBeforeWrites(){
  assertThatThrownBy(()->controller.update(actor,id,request("new","Unknown/Zone"))).isInstanceOf(ApiException.class);
  assertThat(db.sql("select code from merchants where id=?").param(id).query(String.class).single()).isEqualTo("old");
  verify(support,never()).audit(any(),anyString(),anyString(),any());
 }
 @Test void tenantPredicatePreventsForeignUpdatesEvenWithPermissiveSupport(){
  db.sql("update merchants set tenant_id=? where id=?").params(UUID.randomUUID(),id).update();
  assertThatThrownBy(()->controller.update(actor,id,request("new","America/Lima"))).isInstanceOf(ApiException.class);
  assertThat(db.sql("select code from merchants where id=?").param(id).query(String.class).single()).isEqualTo("old");
 }
}
