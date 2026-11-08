package com.delivery.platform.payments.application;

import com.delivery.platform.catalog.common.CatalogSupport;
import com.delivery.platform.catalog.media.infrastructure.MinioCatalogStorage;
import com.delivery.platform.common.ApiException;
import com.delivery.platform.identity.security.IdentityPrincipal;
import java.util.*;
import org.junit.jupiter.api.*;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.springframework.mock.web.MockMultipartFile;
import static org.assertj.core.api.Assertions.*;
import static org.mockito.Mockito.*;

class MerchantYapeServiceTest {
    JdbcClient db;
    MerchantYapeService service;
    MinioCatalogStorage storage = mock(MinioCatalogStorage.class);
    UUID tenant = UUID.randomUUID(), merchant = UUID.randomUUID();
    IdentityPrincipal principal = new IdentityPrincipal(UUID.randomUUID(), tenant, "test", Set.of("TENANT_ADMIN"), Set.of());
    @BeforeEach void setup() {
        db = JdbcClient.create(new DriverManagerDataSource("jdbc:h2:mem:"+UUID.randomUUID()+";MODE=PostgreSQL;DB_CLOSE_DELAY=-1", "sa", ""));
        db.sql("create table merchants(id uuid,tenant_id uuid,status varchar default 'ACTIVE')").update();
        db.sql("create table merchant_yape_settings(tenant_id uuid,merchant_id uuid,enabled boolean,phone varchar,holder_name varchar,qr_object_key varchar,version varchar,updated_at timestamp default now(),primary key(tenant_id,merchant_id))").update();
        db.sql("insert into merchants(id,tenant_id) values (?,?)").params(merchant, tenant).update();
        service = new MerchantYapeService(db, mock(CatalogSupport.class), storage);
        when(storage.put(any(),any(),any())).thenReturn("private/qr.png");
        when(storage.signedUrl("private/qr.png")).thenReturn("signed-url");
    }
    @Test void absentConfigurationIsDisabledAndTenantIsAlwaysChecked() {
        assertThat(service.checkout(principal,merchant).enabled()).isFalse();
        var outsider = new IdentityPrincipal(principal.userId(), UUID.randomUUID(), "other",Set.of(),Set.of());
        assertThatThrownBy(()->service.checkout(outsider,merchant)).isInstanceOf(ApiException.class);
    }
    @Test void disabledSettingsAcceptBlankFieldsAndCashOnlyHidesYape() {
        assertThat(service.save(principal,merchant,false," "," ",null).phone()).isNull();
        org.springframework.test.util.ReflectionTestUtils.setField(service,"configuredProvider","CASH_ONLY");
        assertThat(service.checkout(principal,merchant).enabled()).isFalse();
        assertThatThrownBy(()->service.requireCurrent(principal,merchant,"v1")).isInstanceOf(ApiException.class);
    }
    @Test void manualYapeExposesConfiguredReceiver() {
        db.sql("insert into merchant_yape_settings values(?,?,true,'987654321','Titular','private/qr.png','v1',now())")
            .params(tenant,merchant).update();
        org.springframework.test.util.ReflectionTestUtils.setField(service,"configuredProvider","MANUAL_YAPE");
        assertThat(service.checkout(principal,merchant).enabled()).isTrue();
        assertThat(service.checkout(principal,merchant).qrUrl()).isEqualTo("signed-url");
        assertThat(service.requireCurrent(principal,merchant,"v1").phone()).isEqualTo("987654321");
    }
    @Test void enablingRequiresPeruvianPhoneHolderAndRealQrImage() {
        assertThatThrownBy(()->service.save(principal,merchant,true,"123","Titular",null)).isInstanceOf(ApiException.class);
        assertThatThrownBy(()->service.save(principal,merchant,true,"987654321","",null)).isInstanceOf(ApiException.class);
        assertThatThrownBy(()->service.save(principal,merchant,true,"987654321","Titular",null)).isInstanceOf(ApiException.class);
        var fake = new MockMultipartFile("qr","bad.png","image/png","not an image".getBytes());
        assertThatThrownBy(()->service.save(principal,merchant,true,"987654321","Titular",fake)).isInstanceOf(ApiException.class);
        verifyNoInteractions(storage);
    }
    @Test void imageIsPrivateSignedAndEveryEditChangesVersion() throws Exception {
        var image = new java.awt.image.BufferedImage(2,2,java.awt.image.BufferedImage.TYPE_INT_RGB);
        var out = new java.io.ByteArrayOutputStream(); javax.imageio.ImageIO.write(image,"png",out);
        var qr = new MockMultipartFile("qr","qr.png","image/png",out.toByteArray());
        var first = service.save(principal,merchant,true,"987654321"," Titular ",qr);
        assertThat(first.qrUrl()).isEqualTo("signed-url");
        assertThat(first.holderName()).isEqualTo("Titular");
        var second = service.save(principal,merchant,true,"987654321","Otro",null);
        assertThat(second.version()).isNotEqualTo(first.version());
        assertThatThrownBy(()->service.requireCurrent(principal,merchant,first.version())).isInstanceOf(ApiException.class);
        assertThat(service.requireCurrent(principal,merchant,second.version()).phone()).isEqualTo("987654321");
        service.save(principal,merchant,false,null,null,null);
        assertThatThrownBy(()->service.requireCurrent(principal,merchant,second.version())).isInstanceOf(ApiException.class);
    }
}
