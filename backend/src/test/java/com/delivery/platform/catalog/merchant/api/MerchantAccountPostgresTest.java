package com.delivery.platform.catalog.merchant.api;

import com.delivery.platform.catalog.common.CatalogSupport;
import com.delivery.platform.common.ApiException;
import com.delivery.platform.identity.auth.application.IdentityAccountService;
import com.delivery.platform.identity.security.IdentityPrincipal;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.condition.EnabledIfSystemProperty;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.transaction.support.TransactionTemplate;
import java.util.*;
import static org.assertj.core.api.Assertions.*;
import static org.mockito.Mockito.*;

@EnabledIfSystemProperty(named="identity.migration.jdbcUrl",matches="jdbc:postgresql://.+/postgres")
class MerchantAccountPostgresTest {
    JdbcClient admin, db;
    DriverManagerDataSource source;
    String database;
    UUID tenant=UUID.randomUUID();
    BCryptPasswordEncoder passwords=new BCryptPasswordEncoder(4);

    @BeforeEach void setup() {
        String url=System.getProperty("identity.migration.jdbcUrl");
        String user=System.getenv("IDENTITY_MIGRATION_DB_USER"), password=System.getenv("IDENTITY_MIGRATION_DB_PASSWORD");
        admin=JdbcClient.create(new DriverManagerDataSource(url,user,password));
        database="delivery_merchant_test_"+UUID.randomUUID().toString().replace("-","");
        admin.sql("create database "+database+" template template0").update();
        System.out.println("TEMP_DATABASE_CREATED="+database);
        source=new DriverManagerDataSource(url.substring(0,url.lastIndexOf('/')+1)+database,user,password);
        db=JdbcClient.create(source);
        Flyway.configure().dataSource(source).locations("classpath:db/migration").cleanDisabled(true).load().migrate();
        db.sql("insert into tenants(id,code,name) values(?,'merchant-test','Merchant test')").param(tenant).update();
    }
    @AfterEach void cleanup() {
        if(database!=null && database.matches("delivery_merchant_test_[a-f0-9]{32}")) {
            admin.sql("drop database "+database+" with(force)").update();
            System.out.println("TEMP_DATABASE_DROPPED="+database);
        }
    }
    IdentityPrincipal actor(boolean allowed) {
        return new IdentityPrincipal(UUID.randomUUID(),tenant,"merchant-test",Set.of("TENANT_ADMIN"),
                allowed?Set.of("IDENTITY_USERS_CREATE","IDENTITY_ROLES_ASSIGN"):Set.of());
    }
    MerchantController controller() throws Exception {
        var support=mock(CatalogSupport.class);
        when(support.conflict(anyString(),anyString())).thenAnswer(i->new ApiException(org.springframework.http.HttpStatus.CONFLICT,i.getArgument(0),i.getArgument(1)));
        var constructor=MerchantController.class.getConstructors()[0];
        if(constructor.getParameterCount()==2) return (MerchantController)constructor.newInstance(db,support);
        var provisioner=Class.forName("com.delivery.platform.merchant.application.MerchantAccountProvisioner")
                .getConstructor(JdbcClient.class,IdentityAccountService.class)
                .newInstance(db,new IdentityAccountService(db,passwords));
        return (MerchantController)constructor.newInstance(db,support,provisioner);
    }
    MerchantController.Save request(String code,String email) throws Exception {
        return new ObjectMapper().readValue("""
            {"code":"%s","name":"Test shop","merchantType":"RESTAURANT","email":"contact@example.test",
             "defaultCurrency":"PEN","timezone":"America/Lima",
             "portalAccess":{"email":"%s","firstName":"Shop","lastName":"Owner","password":"safe-test-password"}}
            """.formatted(code,email),MerchantController.Save.class);
    }
    MerchantController.Merchant create(String code,String email,boolean allowed) throws Exception {
        var controller=controller(); var request=request(code,email);
        return new TransactionTemplate(new DataSourceTransactionManager(source)).execute(status->controller.create(actor(allowed),request));
    }
    @Test void createsScopedAccountAndAssignsOnlyItsFutureBranches() throws Exception {
        var merchant=create("shop-one"," Owner@Example.test ",true);
        UUID user=db.sql("select id from users where email='owner@example.test'").query(UUID.class).single();
        String hash=db.sql("select password_hash from identity_accounts where email='owner@example.test'").query(String.class).single();
        assertThat(passwords.matches("safe-test-password",hash)).isTrue();
        assertThat(db.sql("select r.code from user_roles ur join roles r on r.id=ur.role_id where ur.user_id=?").param(user).query(String.class).list()).containsExactly("MERCHANT_PORTAL_OPERATOR");
        assertThat(db.sql("select count(*) from tenant_memberships where user_id=? and tenant_id=? and active").params(user,tenant).query(Integer.class).single()).isEqualTo(1);
        UUID membership=db.sql("select id from merchant_memberships where user_id=? and merchant_id=? and role_code='OWNER' and active").params(user,merchant.id()).query(UUID.class).single();
        UUID ownBranch=branch(merchant.id(),"one");
        UUID other=UUID.randomUUID();
        db.sql("insert into merchants(id,tenant_id,code,name,merchant_type) values(?,?,'other','Other','RESTAURANT')").params(other,tenant).update();
        branch(other,"other");
        assertThat(db.sql("select branch_id from merchant_branch_assignments where membership_id=?").param(membership).query(UUID.class).list()).containsExactly(ownBranch);
        assertThat(db.sql("select p.code from permissions p join role_permissions rp on rp.permission_id=p.id join user_roles ur on ur.role_id=rp.role_id where ur.user_id=?").param(user).query(String.class).list())
                .contains("MERCHANT_PORTAL_ACCESS","MERCHANT_ORDERS_MANAGE","MERCHANT_DELIVERY_ASSIGN","MERCHANT_ORDER_HAND_TO_COURIER")
                .doesNotContain("PLATFORM_MANAGE","IDENTITY_USERS_CREATE");
    }
    @Test void supportsExpandedMerchantTypesAndRejectsUnknownValues() {
        for(String type:List.of("RESTAURANT","GROCERY","PHARMACY","RETAIL","DARK_STORE","OTHER",
                "POLLERIA","BURGERS","CHIFA","ICE_CREAM","BODEGA","SERVICES")) {
            db.sql("insert into merchants(tenant_id,code,name,merchant_type) values(?,?,?,?)")
                    .params(tenant,type.toLowerCase(),type,type).update();
        }
        assertThat(db.sql("select count(*) from merchants where tenant_id=?").param(tenant).query(Integer.class).single()).isEqualTo(12);
        assertThatThrownBy(()->db.sql("insert into merchants(tenant_id,code,name,merchant_type) values(?,'invalid','Invalid','UNKNOWN')")
                .param(tenant).update()).isInstanceOf(org.springframework.dao.DataIntegrityViolationException.class);
    }
    UUID branch(UUID merchant,String code) {
        UUID id=UUID.randomUUID();
        db.sql("insert into branches(id,tenant_id,merchant_id,code,name,address_line) values(?,?,?,?,'Branch','Test address')").params(id,tenant,merchant,code).update();
        return id;
    }
    @Test void existingIdentityIsNotOverwrittenAndMerchantRollsBack() throws Exception {
        var identities=new IdentityAccountService(db,passwords);
        var existing=identities.createForManagedUser("existing@example.test","original-password");
        assertThatThrownBy(()->create("duplicate","existing@example.test",true)).isInstanceOf(ApiException.class);
        assertThat(db.sql("select count(*) from merchants").query(Integer.class).single()).isZero();
        assertThat(db.sql("select password_hash from identity_accounts where id=?").param(existing.id()).query(String.class).single()).isEqualTo(existing.passwordHash());
    }
    @Test void merchantCreatorWithoutIdentityPermissionsCannotProvisionAccounts() {
        assertThatThrownBy(()->create("unauthorized","new@example.test",false)).isInstanceOf(ApiException.class);
        assertThat(db.sql("select count(*) from merchants").query(Integer.class).single()).isZero();
        assertThat(db.sql("select count(*) from identity_accounts").query(Integer.class).single()).isZero();
    }
    @Test void newOperatorRolesIncludeDeliveryPermissions() {
        db.sql("delete from roles where tenant_id=? and code='MERCHANT_PORTAL_OPERATOR'").param(tenant).update(); UUID role=UUID.randomUUID();
        db.sql("insert into roles(id,tenant_id,code,name) values(?,?,'MERCHANT_PORTAL_OPERATOR','Comercio')").params(role,tenant).update();
        assertThat(db.sql("select p.code from permissions p join role_permissions rp on rp.permission_id=p.id where rp.role_id=?").param(role).query(String.class).list())
                .contains("MERCHANT_DELIVERY_ASSIGN","MERCHANT_DELIVERY_VIEW_COURIERS","MERCHANT_ORDER_HAND_TO_COURIER");
    }
    @Test void inactiveMerchantCannotBeOperatedWhileOtherMerchantsRemainAccessible() throws Exception {
        var merchant=create("scoped","scoped@example.test",true);
        UUID user=db.sql("select id from users where email='scoped@example.test'").query(UUID.class).single();
        var operator=new IdentityPrincipal(user,tenant,"merchant-test",Set.of("MERCHANT_PORTAL_OPERATOR"),Set.of("MERCHANT_PORTAL_ACCESS"));
        var portal=new com.delivery.platform.merchant.application.MerchantPortalService(db,mock(com.delivery.platform.tracking.realtime.RealtimeGateway.class));
        assertThat(portal.context(operator).merchants()).isEmpty();
        db.sql("update merchants set status='ACTIVE' where id=?").param(merchant.id()).update();
        UUID branch=branch(merchant.id(),"visible");
        assertThat(portal.context(operator).merchants()).hasSize(1);
        org.springframework.test.util.ReflectionTestUtils.invokeMethod(portal,"access",operator,merchant.id(),branch);
        assertThatThrownBy(()->org.springframework.test.util.ReflectionTestUtils.invokeMethod(portal,"access",operator,UUID.randomUUID(),null)).isInstanceOf(ApiException.class);
        db.sql("update merchants set status='SUSPENDED' where id=?").param(merchant.id()).update();
        assertThat(portal.context(operator).merchants()).isEmpty();
        assertThatThrownBy(()->org.springframework.test.util.ReflectionTestUtils.invokeMethod(portal,"access",operator,merchant.id(),branch)).isInstanceOf(ApiException.class);
        assertThat(db.sql("select status from users where id=?").param(user).query(String.class).single()).isEqualTo("ACTIVE");
    }
}
