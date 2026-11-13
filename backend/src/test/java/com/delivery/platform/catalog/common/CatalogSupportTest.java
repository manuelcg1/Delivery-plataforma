package com.delivery.platform.catalog.common;

import com.delivery.platform.catalog.cache.CatalogCache;
import com.delivery.platform.common.ApiException;
import com.delivery.platform.identity.security.IdentityPrincipal;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.jdbc.datasource.DriverManagerDataSource;

import java.util.Set;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.mock;

class CatalogSupportTest {
    private JdbcClient db;
    private CatalogSupport support;
    private UUID tenant;
    private UUID operator;
    private UUID firstMerchant;
    private UUID secondMerchant;

    @BeforeEach
    void setUp() {
        var source = new DriverManagerDataSource(
                "jdbc:h2:mem:" + UUID.randomUUID() + ";MODE=PostgreSQL;DB_CLOSE_DELAY=-1", "sa", "");
        db = JdbcClient.create(source);
        db.sql("create table merchants(id uuid primary key, tenant_id uuid not null)").update();
        db.sql("create table branches(id uuid primary key,tenant_id uuid not null,merchant_id uuid not null)").update();
        db.sql("create table products(id uuid primary key, tenant_id uuid not null, merchant_id uuid not null)").update();
        db.sql("create table merchant_memberships(id uuid primary key, tenant_id uuid not null, merchant_id uuid not null, user_id uuid not null, active boolean not null)").update();
        db.sql("create table merchant_branch_assignments(membership_id uuid not null, branch_id uuid not null)").update();
        support = new CatalogSupport(db, mock(CatalogCache.class));
        tenant = UUID.randomUUID();
        operator = UUID.randomUUID();
        firstMerchant = UUID.randomUUID();
        secondMerchant = UUID.randomUUID();
        db.sql("insert into merchants values (:id,:tenant)").param("id", firstMerchant).param("tenant", tenant).update();
        db.sql("insert into merchants values (:id,:tenant)").param("id", secondMerchant).param("tenant", tenant).update();
        db.sql("insert into merchant_memberships values (:id,:tenant,:merchant,:user,true)")
                .param("id", UUID.randomUUID()).param("tenant", tenant).param("merchant", firstMerchant)
                .param("user", operator).update();
    }

    @AfterEach
    void tearDown() {
        db.sql("SHUTDOWN").update();
    }

    @Test
    void platformOwnerAccessesCurrentTenantCatalogButNotAnotherTenant() {
        var owner = new IdentityPrincipal(UUID.randomUUID(), tenant, "platform",
                Set.of("ROLE_PLATFORM_OWNER"), Set.of());
        assertDoesNotThrow(() -> support.merchant(owner, secondMerchant));
        UUID foreignMerchant = UUID.randomUUID();
        db.sql("insert into merchants values (?,?)").params(foreignMerchant, UUID.randomUUID()).update();
        assertThrows(ApiException.class, () -> support.merchant(owner, foreignMerchant));
    }

    @Test
    void operatorCannotReadAnotherMerchantsProductInSameTenant() {
        UUID product = UUID.randomUUID();
        db.sql("insert into products values (:id,:tenant,:merchant)")
                .param("id", product).param("tenant", tenant).param("merchant", secondMerchant).update();
        var principal = new IdentityPrincipal(operator, tenant, "tenant", Set.of("MERCHANT_OPERATOR"), Set.of());

        assertThrows(ApiException.class, () -> support.product(principal, product));
    }

    @Test
    void operatorCanAccessAssignedMerchantAndTenantAdminKeepsTenantScope() {
        UUID product = UUID.randomUUID();
        db.sql("insert into products values (:id,:tenant,:merchant)")
                .param("id", product).param("tenant", tenant).param("merchant", firstMerchant).update();
        var operatorPrincipal = new IdentityPrincipal(operator, tenant, "tenant", Set.of("MERCHANT_OPERATOR"), Set.of());
        var adminPrincipal = new IdentityPrincipal(UUID.randomUUID(), tenant, "tenant", Set.of("TENANT_ADMIN"), Set.of());

        assertDoesNotThrow(() -> support.product(operatorPrincipal, product));
        assertDoesNotThrow(() -> support.merchant(adminPrincipal, secondMerchant));
    }
    @Test
    void portalOperatorCanOnlyAccessAssignedBranchInOwnTenant() {
        UUID assigned=UUID.randomUUID(), unassigned=UUID.randomUUID(), otherMerchantBranch=UUID.randomUUID(), otherTenantBranch=UUID.randomUUID();
        for(UUID branch : java.util.List.of(assigned,unassigned)) db.sql("insert into branches values(?,?,?)").params(branch,tenant,firstMerchant).update();
        db.sql("insert into branches values(?,?,?)").params(otherMerchantBranch,tenant,secondMerchant).update();
        db.sql("insert into branches values(?,?,?)").params(otherTenantBranch,UUID.randomUUID(),firstMerchant).update();
        UUID membership=db.sql("select id from merchant_memberships where user_id=:u").param("u",operator).query(UUID.class).single();
        db.sql("insert into merchant_branch_assignments values(?,?)").params(membership,assigned).update();
        db.sql("insert into merchant_branch_assignments values(?,?)").params(membership,otherTenantBranch).update();
        var principal=new IdentityPrincipal(operator,tenant,"tenant",Set.of("MERCHANT_PORTAL_OPERATOR"),Set.of("MERCHANT_BRANCH_OPERATE"));
        assertDoesNotThrow(()->support.branch(principal,assigned));
        for(UUID denied:java.util.List.of(unassigned,otherMerchantBranch,otherTenantBranch)) assertThrows(ApiException.class,()->support.branch(principal,denied));
        db.sql("update merchant_memberships set active=false where id=:id").param("id",membership).update();
        assertThrows(ApiException.class,()->support.branch(principal,assigned));
    }
}
