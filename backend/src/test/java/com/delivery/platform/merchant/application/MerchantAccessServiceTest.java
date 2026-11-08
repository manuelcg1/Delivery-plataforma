package com.delivery.platform.merchant.application;

import com.delivery.platform.common.ApiException;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.BeforeEach;
import com.delivery.platform.catalog.common.CatalogSupport;
import com.delivery.platform.identity.security.IdentityPrincipal;
import com.delivery.platform.merchant.api.MerchantAccessDtos.Update;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import java.util.*;
import static org.mockito.Mockito.*;
import static org.junit.jupiter.api.Assertions.*;

class MerchantAccessServiceTest {
    JdbcClient db;
    DriverManagerDataSource source;
    MerchantAccessService service;
    CatalogSupport support;
    BCryptPasswordEncoder passwords=new BCryptPasswordEncoder(4);
    UUID tenant=UUID.randomUUID(), merchant=UUID.randomUUID(), user=UUID.randomUUID(), identity=UUID.randomUUID();
    IdentityPrincipal actor=new IdentityPrincipal(UUID.randomUUID(),tenant,"test",Set.of("TENANT_ADMIN"),Set.of());
    @BeforeEach void setup() {
        source=new DriverManagerDataSource("jdbc:h2:mem:"+UUID.randomUUID()+";MODE=PostgreSQL;DB_CLOSE_DELAY=-1","sa","");
        db=JdbcClient.create(source);
        for (String sql:List.of(
            "create table users(id uuid primary key,tenant_id uuid,identity_id uuid,email varchar,first_name varchar,last_name varchar,password_hash varchar,status varchar,updated_at timestamp)",
            "create table identity_accounts(id uuid primary key,email varchar unique,legacy_email varchar,password_hash varchar,email_conflict boolean,updated_at timestamp,status varchar default 'ACTIVE')",
            "create table tenant_memberships(identity_id uuid,tenant_id uuid,user_id uuid,active boolean)",
            "create table merchant_memberships(user_id uuid,tenant_id uuid,merchant_id uuid,active boolean,role_code varchar)",
            "create table roles(id uuid,tenant_id uuid,code varchar)","create table user_roles(user_id uuid,role_id uuid)",
            "create table refresh_tokens(user_id uuid,revoked_at timestamp)")) db.sql(sql).update();
        String hash=passwords.encode("original-password");
        db.sql("insert into users values(?,?,?,'owner@test.local','Old','Owner',?,'ACTIVE',now())").params(user,tenant,identity,hash).update();
        db.sql("insert into identity_accounts(id,email,legacy_email,password_hash,email_conflict,updated_at) values(?,'owner@test.local','owner@test.local',?,false,now())").params(identity,hash).update();
        db.sql("insert into tenant_memberships values(?,?,?,true)").params(identity,tenant,user).update();
        db.sql("insert into merchant_memberships values(?,?,?,true,'OWNER')").params(user,tenant,merchant).update();
        db.sql("insert into refresh_tokens values(?,null)").param(user).update();
        support=mock(CatalogSupport.class); service=new MerchantAccessService(db,support,passwords);
    }
    @Test void updatesBothLoginCopiesAndPreservesBlankPasswordAndSessions() {
        String before=db.sql("select password_hash from users").query(String.class).single();
        var result=service.update(actor,merchant,user,new Update("owner@test.local","New","Name",""));
        assertTrue(result.editable()); assertEquals("New",result.firstName());
        assertEquals(before,db.sql("select password_hash from users").query(String.class).single());
        assertEquals(1,db.sql("select count(*) from refresh_tokens where revoked_at is null").query(Integer.class).single());
    }
    @Test void changesPasswordAndEmailAndRevokesOnlyIdentitySessions() {
        db.sql("insert into refresh_tokens values(?,null)").param(UUID.randomUUID()).update();
        service.update(actor,merchant,user,new Update("NEW@test.local","New","Name","replacement-password"));
        String hash=db.sql("select password_hash from users").query(String.class).single();
        assertTrue(passwords.matches("replacement-password",hash));
        assertEquals(hash,db.sql("select password_hash from identity_accounts").query(String.class).single());
        assertEquals("new@test.local",db.sql("select email from identity_accounts").query(String.class).single());
        assertEquals(1,db.sql("select count(*) from refresh_tokens where revoked_at is null").query(Integer.class).single());
    }
    @Test void blocksOtherTenantMembershipAndOtherMerchantEvenInactive() {
        db.sql("insert into tenant_memberships values(?,?,?,false)").params(identity,UUID.randomUUID(),UUID.randomUUID()).update();
        assertFalse(service.list(actor,merchant).getFirst().editable());
        assertThrows(ApiException.class,()->service.update(actor,merchant,user,new Update("x@test.local","X","Y",null)));
        db.sql("delete from tenant_memberships where tenant_id<>?").param(tenant).update();
        db.sql("insert into merchant_memberships values(?,?,?,false,'OWNER')").params(user,tenant,UUID.randomUUID()).update();
        assertFalse(service.list(actor,merchant).getFirst().editable());
    }
    @Test void rejectsDuplicateLegacyEmailWithoutChangingUser() {
        db.sql("insert into identity_accounts(id,email,legacy_email,password_hash,email_conflict,updated_at) values(?,null,'reserved@test.local','hash',true,now())").param(UUID.randomUUID()).update();
        assertThrows(ApiException.class,()->service.update(actor,merchant,user,new Update("RESERVED@test.local","X","Y",null)));
        assertEquals("owner@test.local",db.sql("select email from users").query(String.class).single());
    }
    @Test void wrongTenantOrMerchantCannotSelectAccount() {
        var outsider=new IdentityPrincipal(actor.userId(),UUID.randomUUID(),"other",Set.of(),Set.of());
        assertTrue(service.list(outsider,merchant).isEmpty());
        assertThrows(ApiException.class,()->service.update(actor,UUID.randomUUID(),user,new Update("x@test.local","X","Y",null)));
        verify(support).merchant(outsider,merchant);
    }
    @Test void rollsBackCredentialsAndRevocationIfAuditFails() {
        doThrow(new IllegalStateException("audit unavailable")).when(support)
            .audit(actor,"MERCHANT_ACCESS_UPDATED","MERCHANT",merchant);
        var transaction=new TransactionTemplate(new DataSourceTransactionManager(source));
        assertThrows(IllegalStateException.class,()->transaction.execute(status ->
            service.update(actor,merchant,user,new Update("replacement@test.local","New","Name","replacement-password"))));
        assertEquals("owner@test.local",db.sql("select email from identity_accounts").query(String.class).single());
        assertTrue(passwords.matches("original-password",db.sql("select password_hash from users").query(String.class).single()));
        assertEquals(1,db.sql("select count(*) from refresh_tokens where revoked_at is null").query(Integer.class).single());
    }
    @Test void blocksAccountWithAdministrativeRole() {
        UUID role=UUID.randomUUID();
        db.sql("insert into roles values(?,?,'TENANT_ADMIN')").params(role,tenant).update();
        db.sql("insert into user_roles values(?,?)").params(user,role).update();
        assertFalse(service.list(actor,merchant).getFirst().editable());
        assertThrows(ApiException.class,()->service.update(actor,merchant,user,new Update("new@test.local","New","Name",null)));
    }
    @Test void blankPasswordPreservesCanonicalIdentityHashAndRepairsUserCopy() {
        String canonical=db.sql("select password_hash from identity_accounts").query(String.class).single();
        db.sql("update users set password_hash=?").param(passwords.encode("legacy-password")).update();
        service.update(actor,merchant,user,new Update("owner@test.local","New","Name",""));
        assertEquals(canonical,db.sql("select password_hash from identity_accounts").query(String.class).single());
        assertEquals(canonical,db.sql("select password_hash from users").query(String.class).single());
    }
    @Test void globalRoleCannotBeMutatedThroughMerchantAccess() {
        UUID role=UUID.randomUUID();
        db.sql("insert into roles(id,code) values(?,'MERCHANT_OPERATOR')").param(role).update();
        db.sql("insert into user_roles values(?,?)").params(user,role).update();
        assertFalse(service.list(actor,merchant).getFirst().editable());
        assertThrows(ApiException.class,()->service.update(actor,merchant,user,new Update("new@test.local","New","Name",null)));
    }
    @Test void passwordLimitsUseUtf8BytesAndBlankPreserves() {
        assertDoesNotThrow(() -> MerchantAccessService.validatePassword(null));
        assertDoesNotThrow(() -> MerchantAccessService.validatePassword(""));
        assertThrows(ApiException.class, () -> MerchantAccessService.validatePassword(" ".repeat(10)));
        assertDoesNotThrow(() -> MerchantAccessService.validatePassword("a".repeat(72)));
        assertThrows(ApiException.class, () -> MerchantAccessService.validatePassword("short"));
        assertThrows(ApiException.class, () -> MerchantAccessService.validatePassword("á".repeat(37)));
    }
}
