package com.delivery.platform.catalog.merchant.api;
import com.delivery.platform.catalog.common.CatalogSupport;
import com.delivery.platform.catalog.media.application.MerchantMediaService;
import com.delivery.platform.catalog.media.infrastructure.MinioCatalogStorage;
import com.delivery.platform.identity.security.IdentityPrincipal;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import java.util.*;
import static org.assertj.core.api.Assertions.*;
import static org.mockito.Mockito.*;
class MerchantMediaReadTest {
 @Test void signsOnlyStoredImagesInAuthenticatedTenant(){
  UUID tenant=UUID.randomUUID(),merchant=UUID.randomUUID();
  var p=new IdentityPrincipal(UUID.randomUUID(),tenant,"t",Set.of(),Set.of());
  var db=JdbcClient.create(new DriverManagerDataSource("jdbc:h2:mem:"+UUID.randomUUID()+";DB_CLOSE_DELAY=-1","sa",""));
  db.sql("create table merchants(id uuid,tenant_id uuid,logo_object_key varchar,banner_object_key varchar)").update();
  db.sql("insert into merchants values(?,?,?,null)").params(merchant,tenant,"own-key").update();
  var support=mock(CatalogSupport.class);var storage=mock(MinioCatalogStorage.class);
  when(storage.signedUrl("own-key")).thenReturn("https://images.test/signed");
  var service=new MerchantMediaService(db,support,storage);
  assertThat(service.read(p,merchant,MerchantMediaService.Type.LOGO).url()).isEqualTo("https://images.test/signed");
  assertThat(service.read(p,merchant,MerchantMediaService.Type.BANNER).url()).isNull();
  db.sql("update merchants set tenant_id=?").param(UUID.randomUUID()).update();
  assertThat(service.read(p,merchant,MerchantMediaService.Type.LOGO).url()).isNull();
  verify(storage,times(1)).signedUrl(anyString());verify(support,times(3)).merchant(p,merchant);
 }
}
