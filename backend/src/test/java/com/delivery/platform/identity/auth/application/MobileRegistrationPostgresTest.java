package com.delivery.platform.identity.auth.application;

import com.delivery.platform.common.ApiException;
import com.delivery.platform.delivery.application.DeliveryService;
import com.delivery.platform.identity.auth.api.AuthDtos.*;
import com.delivery.platform.identity.security.*;
import java.util.*;
import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.condition.EnabledIfSystemProperty;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.jdbc.datasource.*;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.transaction.support.TransactionTemplate;
import static org.assertj.core.api.Assertions.*;
import static org.mockito.Mockito.*;

@EnabledIfSystemProperty(named="identity.migration.jdbcUrl",matches="jdbc:postgresql://.+/postgres")
class MobileRegistrationPostgresTest {
    JdbcClient admin,db;
    String database;
    AuthService service;
    TransactionTemplate tx;
    UUID tenant,other;
    JwtService jwt;
    @BeforeEach void setup(){
        String url=System.getProperty("identity.migration.jdbcUrl");
        String username=System.getenv("IDENTITY_MIGRATION_DB_USER"),password=System.getenv("IDENTITY_MIGRATION_DB_PASSWORD");
        admin=JdbcClient.create(new DriverManagerDataSource(url,username,password));
        database="delivery_mobile_test_"+UUID.randomUUID().toString().replace("-","");
        admin.sql("create database "+database+" template template0").update();
        var source=new DriverManagerDataSource(url.substring(0,url.lastIndexOf('/')+1)+database,username,password);
        Flyway.configure().dataSource(source).locations("classpath:db/migration").load().migrate();
        db=JdbcClient.create(source);tx=new TransactionTemplate(new DataSourceTransactionManager(source));
        var passwords=new BCryptPasswordEncoder(4);
        jwt=new JwtService(UUID.randomUUID().toString(),15);
        service=new AuthService(db,passwords,jwt,mock(JavaMailSender.class),new IdentityPrincipalLoader(db),new IdentityAccountService(db,passwords));
        service.mobileTenantCode="mobile-default";service.refreshDays=7;service.maxAttempts=5;service.lockMinutes=15;
        tenant=UUID.randomUUID();other=UUID.randomUUID();
        db.sql("insert into tenants(id,code,name) values(?,'mobile-default','Default'),(?,'mobile-other','Other')").params(tenant,other).update();
    }
    @AfterEach void cleanup(){if(database!=null&&database.matches("delivery_mobile_test_[a-f0-9]{32}"))admin.sql("drop database "+database+" with(force)").update();}
    Object register(String email,MobileProfile profile){return tx.execute(s->service.registerMobile(new RegisterMobile("Ana","Cliente",email,"test-password-123","987 654-321",profile),"test","test"));}
    @Test void customerPhoneAndServerTenantArePreservedAndAdministrativeLoginIsUnchanged(){
        var result=(AuthService.Session)register("customer@example.test",MobileProfile.CUSTOMER);
        var user=jwt.parse(result.response().accessToken());
        assertThat(user.tenantId()).isEqualTo(tenant);
        assertThat(user.roles()).contains("CUSTOMER").doesNotContain("TENANT_ADMIN","COURIER");
        assertThat(db.sql("select phone from users where id=?").param(user.userId()).query(String.class).single()).isEqualTo("+51987654321");
        var login=service.loginMobile(new Login("customer@example.test","test-password-123","mobile-other"),"test","test");
        assertThat(jwt.parse(login.response().accessToken()).tenantId()).isEqualTo(tenant);
        assertThat(jwt.parse(service.login(new Login("customer@example.test","test-password-123","mobile-default"),"test","test").response().accessToken()).userId()).isEqualTo(user.userId());
        service.mobileTenantCode="";
        assertThatThrownBy(()->service.loginMobile(new Login("customer@example.test","test-password-123",null),"test","test")).isInstanceOf(ApiException.class);
    }
    @Test void courierCannotOperateUntilScopedAdministrativeActivation(){
        var adminSession=(AuthService.Session)register("admin-actor@example.test",MobileProfile.CUSTOMER);
        UUID actor=jwt.parse(adminSession.response().accessToken()).userId();
        long before=db.sql("select count(*) from refresh_tokens").query(Long.class).single();
        assertThat(register("courier@example.test",MobileProfile.COURIER)).isInstanceOf(PendingApproval.class);
        assertThat(db.sql("select count(*) from refresh_tokens").query(Long.class).single()).isEqualTo(before);
        UUID courier=db.sql("select id from courier_profiles where tenant_id=?").param(tenant).query(UUID.class).single();
        assertThat(db.sql("select status from courier_profiles where id=?").param(courier).query(String.class).single()).isEqualTo("INACTIVE");
        assertThatThrownBy(()->service.loginMobile(new Login("courier@example.test","wrong-password",null),"test","test")).isInstanceOfSatisfying(ApiException.class,e->assertThat(e.status).isEqualTo(HttpStatus.UNAUTHORIZED));
        assertThatThrownBy(()->service.loginMobile(new Login("courier@example.test","test-password-123",null),"test","test")).isInstanceOfSatisfying(ApiException.class,e->assertThat(e.code).isEqualTo("COURIER_PENDING_APPROVAL"));
        assertThatThrownBy(()->service.login(new Login("courier@example.test","test-password-123","mobile-default"),"test","test")).isInstanceOfSatisfying(ApiException.class,e->assertThat(e.code).isEqualTo("COURIER_PENDING_APPROVAL"));
        var delivery=new DeliveryService(db,null,null);
        var manager=new IdentityPrincipal(actor,tenant,"mobile-default",Set.of("TENANT_ADMIN"),Set.of("COURIER_MANAGE"));
        var outsider=new IdentityPrincipal(actor,other,"mobile-other",Set.of("TENANT_ADMIN"),Set.of("COURIER_MANAGE"));
        assertThatThrownBy(()->tx.execute(s->delivery.activateCourier(outsider,courier))).isInstanceOf(ApiException.class);
        assertThatThrownBy(()->tx.execute(s->delivery.activateCourier(new IdentityPrincipal(actor,tenant,"mobile-default",Set.of("COURIER"),Set.of()),courier))).isInstanceOf(ApiException.class);
        assertThat(tx.execute(s->delivery.activateCourier(manager,courier)).status()).isEqualTo("ACTIVE");
        assertThat(tx.execute(s->delivery.activateCourier(manager,courier)).status()).isEqualTo("ACTIVE");
        assertThat(jwt.parse(service.loginMobile(new Login("courier@example.test","test-password-123",null),"test","test").response().accessToken()).roles()).contains("COURIER");
        assertThat(db.sql("select count(*) from audit_logs where action='COURIER_ACTIVATED' and entity_id=?").param(courier).query(Integer.class).single()).isEqualTo(1);
    }
    @Test void registrationRollsBackWhenRequestedRoleIsDisabled(){
        db.sql("update roles set active=false where tenant_id=? and code='COURIER'").param(tenant).update();
        assertThatThrownBy(()->register("rollback@example.test",MobileProfile.COURIER)).isInstanceOf(ApiException.class);
        assertThat(db.sql("select count(*) from users where email='rollback@example.test'").query(Integer.class).single()).isZero();
        assertThat(db.sql("select count(*) from identity_accounts where email='rollback@example.test'").query(Integer.class).single()).isZero();
    }
}
