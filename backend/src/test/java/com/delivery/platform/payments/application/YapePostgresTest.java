package com.delivery.platform.payments.application;

import com.delivery.platform.catalog.common.CatalogSupport;
import com.delivery.platform.catalog.media.infrastructure.MinioCatalogStorage;
import com.delivery.platform.common.ApiException;
import com.delivery.platform.identity.security.IdentityPrincipal;
import com.delivery.platform.payments.domain.PaymentTypes.Method;
import java.util.*;
import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.condition.EnabledIfSystemProperty;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.jdbc.datasource.*;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.transaction.support.TransactionTemplate;
import static org.assertj.core.api.Assertions.*;
import static org.mockito.Mockito.*;

@EnabledIfSystemProperty(named="identity.migration.jdbcUrl",matches="jdbc:postgresql://.+/postgres")
class YapePostgresTest {
    JdbcClient admin,db;
    String database;
    DriverManagerDataSource source;
    UUID tenant=UUID.randomUUID(), merchant=UUID.randomUUID(), user=UUID.randomUUID(), order=UUID.randomUUID();
    @BeforeEach void setup() {
        String url=System.getProperty("identity.migration.jdbcUrl");
        String username=System.getenv("IDENTITY_MIGRATION_DB_USER"),password=System.getenv("IDENTITY_MIGRATION_DB_PASSWORD");
        admin=JdbcClient.create(new DriverManagerDataSource(url,username,password));
        database="delivery_yape_test_"+UUID.randomUUID().toString().replace("-","");
        admin.sql("create database "+database+" template template0").update();
        source=new DriverManagerDataSource(url.substring(0,url.lastIndexOf('/')+1)+database,username,password);
        db=JdbcClient.create(source);
        Flyway.configure().dataSource(source).locations("classpath:db/migration").cleanDisabled(true).load().migrate();
        db.sql("insert into tenants(id,code,name) values(?,'yape-test','Yape test')").param(tenant).update();
        UUID identity=UUID.randomUUID();
        db.sql("insert into identity_accounts(id,email,password_hash,last_tenant_id) values(?,'test@example.test','test-only',?)").params(identity,tenant).update();
        db.sql("insert into users(id,tenant_id,identity_id,email,password_hash,first_name,last_name) values(?,?,?,'test@example.test','test-only','Test','Customer')").params(user,tenant,identity).update();
        db.sql("insert into tenant_memberships(identity_id,tenant_id,user_id) values(?,?,?)").params(identity,tenant,user).update();
        db.sql("insert into merchants(id,tenant_id,code,name,merchant_type,status) values(?,?,'shop','Shop','RESTAURANT','ACTIVE')").params(merchant,tenant).update();
        UUID branch=UUID.randomUUID(), address=UUID.randomUUID();
        db.sql("insert into branches(id,tenant_id,merchant_id,code,name,address_line) values(?,?,?,'main','Main','Street')").params(branch,tenant,merchant).update();
        db.sql("insert into delivery_addresses(id,tenant_id,customer_id,label,recipient_name,phone,address_line) values(?,?,?,'Home','Test','987654321','Street')").params(address,tenant,user).update();
        db.sql("insert into orders(id,tenant_id,order_number,customer_id,merchant_id,branch_id,delivery_address_id,subtotal,total,currency) values(?,?,'Y001',?,?,?,?,25,25,'PEN')").params(order,tenant,user,merchant,branch,address).update();
    }
    @AfterEach void cleanup(){if(database!=null&&database.matches("delivery_yape_test_[a-f0-9]{32}"))admin.sql("drop database "+database+" with(force)").update();}
    @Test void migrationsAndPrivateConfigurationProduceOnlyPendingManualPayment() throws Exception {
        var storage=mock(MinioCatalogStorage.class);
        when(storage.put(any(),any(),any())).thenReturn("tenant/private/qr.png");
        when(storage.signedUrl(any())).thenReturn("signed-url");
        var settings=new MerchantYapeService(db,mock(CatalogSupport.class),storage);
        var actor=new IdentityPrincipal(user,tenant,"yape-test",Set.of("CUSTOMER"),Set.of());
        var tx=new TransactionTemplate(new DataSourceTransactionManager(source));
        var out=new java.io.ByteArrayOutputStream();
        javax.imageio.ImageIO.write(new java.awt.image.BufferedImage(2,2,java.awt.image.BufferedImage.TYPE_INT_RGB),"png",out);
        var file=new MockMultipartFile("qr","qr.png","image/png",out.toByteArray());
        var initial=tx.execute(s->settings.save(actor,merchant,true,"987654321","Titular",file));
        var updated=tx.execute(s->settings.save(actor,merchant,true,"987654321","Nuevo titular",null));
        assertThat(updated.version()).isNotEqualTo(initial.version());
        var provider=mock(PaymentProvider.class);when(provider.code()).thenReturn("SIMULATED");
        var payments=new PaymentService(db,List.of(provider),"SIMULATED",settings);
        var payment=tx.execute(s->payments.create(actor,order,Method.YAPE,null,"request-key",true,updated.version()));
        assertThat(payment.provider()).isEqualTo("MANUAL_YAPE");
        assertThat(payment.status().name()).isEqualTo("PENDING");
        assertThat(db.sql("select yape_receiver_holder from payments where id=?").param(payment.id()).query(String.class).single()).isEqualTo("Nuevo titular");
        assertThat(db.sql("select payment_status from orders where id=?").param(order).query(String.class).single()).isEqualTo("PENDING");
        assertThat(db.sql("select count(*) from payment_attempts").query(Integer.class).single()).isZero();
        assertThatThrownBy(()->payments.confirm(actor,payment.id())).isInstanceOf(ApiException.class);
        var outsider=new IdentityPrincipal(user,UUID.randomUUID(),"other",Set.of("CUSTOMER"),Set.of());
        assertThatThrownBy(()->settings.checkout(outsider,merchant)).isInstanceOf(ApiException.class);
        assertThatThrownBy(()->payments.create(outsider,order,Method.YAPE,null,"other-key",true,updated.version())).isInstanceOf(ApiException.class);
        verify(provider,never()).process(any(),any(),any());
    }
}
