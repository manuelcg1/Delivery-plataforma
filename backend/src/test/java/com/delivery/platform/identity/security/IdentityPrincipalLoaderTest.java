package com.delivery.platform.identity.security;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.jdbc.datasource.DriverManagerDataSource;

import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class IdentityPrincipalLoaderTest {
    private JdbcClient db;
    private DriverManagerDataSource source;
    private IdentityPrincipalLoader loader;
    private UUID platformTenant;
    private UUID businessTenant;
    private UUID owner;
    private UUID ownerRole;
    private UUID tenantAdminRole;
    private UUID globalPermission;
    private UUID businessPermission;

    @BeforeEach
    void setUp() {
        source = new DriverManagerDataSource(
                "jdbc:h2:mem:" + UUID.randomUUID() + ";MODE=PostgreSQL;DB_CLOSE_DELAY=-1", "sa", "");
        db = JdbcClient.create(source);
        db.sql("create table tenants(id uuid primary key,code varchar,status varchar)").update();
        db.sql("create table identity_accounts(id uuid primary key,status varchar)").update();
        db.sql("create table users(id uuid primary key,identity_id uuid,tenant_id uuid,status varchar)").update();
        db.sql("create table tenant_memberships(id uuid primary key,identity_id uuid,tenant_id uuid,user_id uuid,active boolean)").update();
        db.sql("create table roles(id uuid primary key,tenant_id uuid,code varchar,active boolean)").update();
        db.sql("create table user_roles(user_id uuid,role_id uuid)").update();
        db.sql("create table permissions(id uuid primary key,code varchar)").update();
        db.sql("create table role_permissions(role_id uuid,permission_id uuid)").update();
        loader = new IdentityPrincipalLoader(db);

        platformTenant = UUID.randomUUID();
        businessTenant = UUID.randomUUID();
        owner = UUID.randomUUID();
        UUID ownerIdentity = UUID.randomUUID();
        ownerRole = UUID.randomUUID();
        tenantAdminRole = UUID.randomUUID();
        globalPermission = UUID.randomUUID();
        businessPermission = UUID.randomUUID();
        db.sql("insert into tenants values (:id,'platform','ACTIVE')").param("id", platformTenant).update();
        db.sql("insert into tenants values (:id,'north-shop','ACTIVE')").param("id", businessTenant).update();
        db.sql("insert into identity_accounts values (:id,'ACTIVE')").param("id", ownerIdentity).update();
        db.sql("insert into users values (:id,:identity,:tenant,'ACTIVE')")
                .param("id", owner).param("identity", ownerIdentity).param("tenant", platformTenant).update();
        db.sql("insert into tenant_memberships values (:id,:identity,:tenant,:user,true)")
                .param("id", UUID.randomUUID()).param("identity", ownerIdentity)
                .param("tenant", platformTenant).param("user", owner).update();
        db.sql("insert into roles values (:id,null,'ROLE_PLATFORM_OWNER',true)").param("id", ownerRole).update();
        db.sql("insert into roles values (:id,:tenant,'TENANT_ADMIN',true)")
                .param("id", tenantAdminRole).param("tenant", businessTenant).update();
        db.sql("insert into user_roles values (:user,:role)").param("user", owner).param("role", ownerRole).update();
        db.sql("insert into permissions values (:id,'PLATFORM_MANAGE')").param("id", globalPermission).update();
        db.sql("insert into permissions values (:id,'CATALOG_PRODUCTS_UPDATE')").param("id", businessPermission).update();
        db.sql("insert into role_permissions values (:role,:permission)")
                .param("role", ownerRole).param("permission", globalPermission).update();
        db.sql("insert into role_permissions values (:role,:permission)")
                .param("role", tenantAdminRole).param("permission", businessPermission).update();
    }

    @AfterEach
    void tearDown() throws Exception {
        try (var connection = source.getConnection(); var statement = connection.createStatement()) {
            statement.execute("SHUTDOWN");
        }
    }

    @Test
    void platformOwnerReceivesTenantPermissionsOnlyForValidatedActiveContext() {
        var principal = loader.load(owner, businessTenant).orElseThrow();

        assertTrue(principal.roles().contains("ROLE_PLATFORM_OWNER"));
        assertTrue(principal.roles().contains("TENANT_ADMIN"));
        assertTrue(principal.permissions().contains("PLATFORM_MANAGE"));
        assertTrue(principal.permissions().contains("CATALOG_PRODUCTS_UPDATE"));

        db.sql("update tenants set status='INACTIVE' where id=:id").param("id", businessTenant).update();
        assertTrue(loader.load(owner, businessTenant).isEmpty());
    }

    @Test
    void inactiveMembershipCannotAuthenticateIntoItsTenant() {
        UUID user = UUID.randomUUID();
        UUID identity = UUID.randomUUID();
        db.sql("insert into identity_accounts values (:id,'ACTIVE')").param("id", identity).update();
        db.sql("insert into users values (:id,:identity,:tenant,'ACTIVE')")
                .param("id", user).param("identity", identity).param("tenant", businessTenant).update();
        db.sql("insert into tenant_memberships values (:id,:identity,:tenant,:user,false)")
                .param("id", UUID.randomUUID()).param("identity", identity)
                .param("tenant", businessTenant).param("user", user).update();

        assertTrue(loader.load(user, businessTenant).isEmpty());
    }
}