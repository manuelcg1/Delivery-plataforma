package com.delivery.platform.identity.auth.application;

import com.delivery.platform.common.ApiException;
import com.delivery.platform.identity.auth.api.AuthDtos.*;
import com.delivery.platform.identity.security.IdentityPrincipalLoader;
import com.delivery.platform.identity.security.JwtService;
import com.delivery.platform.identity.security.IdentityPrincipal;
import com.delivery.platform.identity.user.api.UserController;
import org.springframework.test.util.ReflectionTestUtils;
import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.condition.EnabledIfSystemProperty;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.*;
import static org.assertj.core.api.Assertions.*;
import static org.mockito.Mockito.mock;

/** Opt-in real PostgreSQL test. Creates and drops only the database allocated by this instance. */
@EnabledIfSystemProperty(named="identity.migration.jdbcUrl",matches="jdbc:postgresql://.+/postgres")
class GlobalIdentityMigrationPostgresTest {
    private JdbcClient admin, db;
    private DriverManagerDataSource source;
    private String database;
    private boolean created;
    private final BCryptPasswordEncoder passwords=new BCryptPasswordEncoder(4);
    private final UUID north=UUID.randomUUID(), south=UUID.randomUUID();

    @BeforeEach void createIsolatedDatabase() {
        String url=System.getProperty("identity.migration.jdbcUrl");
        String user=Objects.requireNonNull(System.getenv("IDENTITY_MIGRATION_DB_USER"));
        String password=Objects.requireNonNull(System.getenv("IDENTITY_MIGRATION_DB_PASSWORD"));
        admin=JdbcClient.create(new DriverManagerDataSource(url,user,password));
        database="delivery_migration_test_"+UUID.randomUUID().toString().replace("-","");
        admin.sql("create database "+database+" template template0").update();
        created=true;
        System.out.println("TEMP_DATABASE_CREATED="+database);
        source=new DriverManagerDataSource(url.substring(0,url.lastIndexOf('/')+1)+database,user,password);
        db=JdbcClient.create(source);
    }

    @AfterEach void dropOnlyOwnedDatabase() {
        if(!created) return;
        if(!database.matches("delivery_migration_test_[a-f0-9]{32}")) throw new IllegalStateException("Unexpected database name");
        admin.sql("drop database "+database+" with (force)").update();
        assertThat(admin.sql("select count(*) from pg_database where datname=:name")
            .param("name",database).query(Integer.class).single()).isZero();
        System.out.println("TEMP_DATABASE_DROPPED="+database);
    }

    private Flyway flyway(String target) {
        var config=Flyway.configure().dataSource(source).locations("classpath:db/migration").cleanDisabled(true);
        config.target(target==null?"34":target); // This suite specifically verifies the V34 upgrade.
        return config.load();
    }
    private void migrate(String target) { flyway(target).migrate(); }
    private void tenants() {
        db.sql("insert into tenants(id,code,name) values(?, 'v34-north','North'),(?, 'v34-south','South')")
            .params(north,south).update();
    }
    private UUID user(UUID tenant,String email,String password,String status,int attempts,Integer lockMinutes) {
        UUID id=UUID.randomUUID();
        db.sql("""
            insert into users(id,tenant_id,email,password_hash,first_name,last_name,status,failed_login_attempts,locked_until)
            values(:id,:tenant,:email,:password,'Migration','Fixture',:status,:attempts,
              case when cast(:minutes as integer) is null then null else now()+make_interval(mins=>:minutes) end)
            """).param("id",id).param("tenant",tenant).param("email",email).param("password",passwords.encode(password))
            .param("status",status).param("attempts",attempts).param("minutes",lockMinutes).update();
        UUID role=UUID.randomUUID();
        db.sql("insert into roles(id,tenant_id,code,name) values(?,?,?,'Migration fixture')")
            .params(role,tenant,"TEST_"+id).update();
        db.sql("insert into user_roles values(?,?)").params(id,role).update();
        db.sql("insert into role_permissions(role_id,permission_id) select ?,id from permissions where code='ORDERS_VIEW'")
            .param(role).update();
        return id;
    }
    private void refresh(UUID user,String raw,boolean expired,boolean revoked) throws Exception {
        db.sql("""
            insert into refresh_tokens(user_id,token_hash,expires_at,revoked_at,created_ip,user_agent)
            values(:user,:hash,now()+make_interval(days=>:days),case when :revoked then now() else null end,'127.0.0.1','migration-test')
            """).param("user",user).param("hash",hash(raw)).param("days",expired?-1:7).param("revoked",revoked).update();
    }
    private String hash(String raw) throws Exception {
        return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(raw.getBytes(StandardCharsets.UTF_8)));
    }
    private String snapshot(String table,String excluded) {
        // Table and column names are constants supplied only by these tests.
        return db.sql("select coalesce(jsonb_agg(to_jsonb(t)-'"+excluded+"' order by to_jsonb(t)::text),'[]'::jsonb)::text from "+table+" t")
            .query(String.class).single();
    }
    private AuthService auth() {
        var service=new AuthService(db,passwords,new JwtService(UUID.randomUUID().toString(),15),
            mock(JavaMailSender.class),new IdentityPrincipalLoader(db),new IdentityAccountService(db,passwords));
        service.refreshDays=7; service.maxAttempts=5; service.lockMinutes=15; service.resetMinutes=30;
        return service;
    }

    @Test void emptyDatabaseRunsAllMigrationsAndFlywayDoesNotApplyThemTwice() {
        assertThat(flyway(null).migrate().migrationsExecuted).isEqualTo(34);
        flyway(null).validate();
        assertThat(flyway(null).migrate().migrationsExecuted).isZero();
        assertThat(db.sql("select max(version::integer) from flyway_schema_history where success and version is not null")
            .query(Integer.class).single()).isEqualTo(34);
        assertThat(db.sql("select count(*) from pg_indexes where indexname='uq_identity_accounts_email_ci' and indexdef like '%WHERE%'")
            .query(Integer.class).single()).isEqualTo(1);
    }

    @Test void upgradePreservesCredentialsRolesAndRefreshScopeWithoutMergingHistoricalEmailCollisions() throws Exception {
        migrate("33"); tenants();
        UUID unique=user(north,"Unique@Example.test","unique-password","ACTIVE",2,null);
        UUID duplicateNorth=user(north,"Shared@Example.test","north-password","ACTIVE",0,null);
        UUID duplicateSouth=user(south,"shared@example.TEST","south-password","ACTIVE",0,null);
        UUID inactive=user(north,"inactive@example.test","inactive-password","INACTIVE",0,null);
        UUID locked=user(south,"locked@example.test","locked-password","LOCKED",5,15);
        refresh(unique,"legacy-active",false,false);
        refresh(duplicateNorth,"legacy-expired",true,false);
        refresh(duplicateSouth,"legacy-revoked",false,true);
        String users=snapshot("users","identity_id"), tokens=snapshot("refresh_tokens","context_tenant_id");
        String roles=snapshot("user_roles","ignored"), permissions=snapshot("role_permissions","ignored");

        assertThat(flyway(null).migrate().migrationsExecuted).isEqualTo(1);
        flyway(null).validate();
        assertThat(snapshot("users","identity_id")).isEqualTo(users);
        assertThat(snapshot("refresh_tokens","context_tenant_id")).isEqualTo(tokens);
        assertThat(snapshot("user_roles","ignored")).isEqualTo(roles);
        assertThat(snapshot("role_permissions","ignored")).isEqualTo(permissions);
        assertThat(db.sql("select count(*) from identity_accounts").query(Integer.class).single()).isEqualTo(5);
        assertThat(db.sql("select count(*) from tenant_memberships").query(Integer.class).single()).isEqualTo(5);
        assertThat(db.sql("select count(*) from users u join identity_accounts i on i.id=u.identity_id where i.id<>u.id or i.password_hash<>u.password_hash or i.status<>u.status or i.failed_login_attempts<>u.failed_login_attempts or i.locked_until is distinct from u.locked_until")
            .query(Integer.class).single()).isZero();
        assertThat(db.sql("select count(*) from refresh_tokens r join users u on u.id=r.user_id where r.context_tenant_id is distinct from u.tenant_id")
            .query(Integer.class).single()).isZero();
        assertThat(db.sql("select count(*) from identity_accounts where lower(legacy_email)='shared@example.test' and email is null and email_conflict")
            .query(Integer.class).single()).isEqualTo(2);
        assertThat(db.sql("select email from identity_accounts where id=?").param(unique).query(String.class).single()).isEqualTo("unique@example.test");
        assertThat(new IdentityPrincipalLoader(db).load(inactive,north)).isEmpty();
        assertThat(new IdentityPrincipalLoader(db).load(locked,south)).isEmpty();
        assertThat(new IdentityPrincipalLoader(db).load(unique,south)).isEmpty();
        assertThatThrownBy(() -> db.sql("insert into identity_accounts(email,password_hash) values('UNIQUE@example.test','test-only')").update())
            .isInstanceOf(DataIntegrityViolationException.class);
        assertThatThrownBy(() -> db.sql("insert into tenant_memberships(identity_id,tenant_id,user_id) values(?,?,?)")
            .params(unique,north,unique).update()).isInstanceOf(DataIntegrityViolationException.class);

        var auth=auth();
        assertThat(((Me)auth.login(new Login("unique@example.test","unique-password",null),"test","test").response().user()).id()).isEqualTo(unique);
        assertThatThrownBy(() -> auth.login(new Login("shared@example.test","north-password",null),"test","test"))
            .isInstanceOfSatisfying(ApiException.class,e -> assertThat(e.code).isEqualTo("TENANT_SELECTION_REQUIRED"));
        assertThat(((Me)auth.login(new Login("shared@example.test","north-password","v34-north"),"test","test").response().user()).id()).isEqualTo(duplicateNorth);
        assertThat(((Me)auth.login(new Login("shared@example.test","south-password","v34-south"),"test","test").response().user()).id()).isEqualTo(duplicateSouth);
        assertThat(((Me)auth.refresh("legacy-active","test","test").response().user()).tenant().id()).isEqualTo(north);
        assertThatThrownBy(() -> auth.refresh("legacy-expired","test","test")).isInstanceOf(ApiException.class);
        assertThatThrownBy(() -> auth.refresh("legacy-revoked","test","test")).isInstanceOf(ApiException.class);
    }

    @Test void expiredLegacyLockCanAuthenticateAfterMigrationButCurrentLockStillBlocks() {
        migrate("33"); tenants();
        UUID expired=user(north,"expired-lock@example.test","correct-password","LOCKED",5,-1);
        user(south,"current-lock@example.test","correct-password","LOCKED",5,15);
        user(north,"admin-lock@example.test","correct-password","LOCKED",0,null);
        migrate(null);
        var service=auth();
        assertThat(((Me)service.login(new Login("expired-lock@example.test","correct-password","v34-north"),"test","test").response().user()).id())
            .isEqualTo(expired);
        assertThatThrownBy(() -> service.login(new Login("current-lock@example.test","correct-password","v34-south"),"test","test"))
            .isInstanceOfSatisfying(ApiException.class,e -> assertThat(e.code).isEqualTo("ACCOUNT_LOCKED"));
        assertThatThrownBy(() -> service.login(new Login("admin-lock@example.test","correct-password","v34-north"),"test","test"))
            .isInstanceOf(ApiException.class);
    }

    @Test void migratedInactiveUserCanBeReactivatedByItsTenant() {
        migrate("33"); tenants();
        UUID inactive=user(north,"reactivate@example.test","correct-password","INACTIVE",0,null);
        UUID locked=user(north,"reactivate-locked@example.test","correct-password","LOCKED",0,null);
        UUID adminUser=user(north,"admin@example.test","admin-password","ACTIVE",0,null);
        migrate(null);
        var principal=new IdentityPrincipal(adminUser,north,"v34-north",Set.of(),Set.of());
        var controller=new UserController(db,new IdentityAccountService(db,passwords));
        ReflectionTestUtils.invokeMethod(controller,"status",principal,inactive,new UserController.Status("ACTIVE"));
        assertThat(((Me)auth().login(new Login("reactivate@example.test","correct-password",null),"test","test").response().user()).id()).isEqualTo(inactive);
        ReflectionTestUtils.invokeMethod(controller,"status",principal,inactive,new UserController.Status("LOCKED"));
        assertThatThrownBy(() -> auth().login(new Login("reactivate@example.test","correct-password",null),"test","test"))
            .isInstanceOf(ApiException.class);
        ReflectionTestUtils.invokeMethod(controller,"status",principal,locked,new UserController.Status("ACTIVE"));
        assertThat(new IdentityPrincipalLoader(db).load(locked,north)).isPresent();
        assertThat(((Me)auth().login(new Login("reactivate-locked@example.test","correct-password",null),"test","test").response().user()).id()).isEqualTo(locked);
    }

    @Test void ownerCanLogInAgainAfterSwitchingContextAndLoggingOut() {
        migrate("33"); tenants();
        UUID platform=db.sql("select id from tenants where code='platform'").query(UUID.class).single();
        UUID owner=user(platform,"owner@example.test","owner-password","ACTIVE",0,null);
        db.sql("insert into user_roles select ?,id from roles where tenant_id is null and code='ROLE_PLATFORM_OWNER'").param(owner).update();
        migrate(null);
        var service=auth();
        var session=service.login(new Login("owner@example.test","owner-password",null),"test","test");
        var loader=new IdentityPrincipalLoader(db);
        var switched=service.switchContext(loader.load(owner,platform).orElseThrow(),"v34-north",session.refreshToken(),"test","test");
        service.logout(switched.refreshToken(),loader.load(owner,north).orElseThrow(),"test","test");
        assertThat(((Me)service.login(new Login("owner@example.test","owner-password",null),"test","test").response().user()).tenant().id()).isEqualTo(platform);
        UUID secondProfile=UUID.randomUUID();
        db.sql("insert into users(id,tenant_id,identity_id,email,password_hash,first_name,last_name,status) select ?,?,identity_id,email,password_hash,first_name,last_name,'ACTIVE' from users where id=?")
            .params(secondProfile,north,owner).update();
        db.sql("insert into tenant_memberships(identity_id,tenant_id,user_id) values(?,?,?)").params(owner,north,secondProfile).update();
        db.sql("update identity_accounts set last_tenant_id=? where id=?").params(south,owner).update();
        assertThatThrownBy(() -> service.login(new Login("owner@example.test","owner-password",null),"test","test"))
            .isInstanceOfSatisfying(ApiException.class,e -> assertThat(e.code).isEqualTo("TENANT_SELECTION_REQUIRED"));
    }

    @Test void tenantStatusChangesRespectSharedIdentityAndOtherTenants() {
        migrate("33"); tenants();
        UUID member=user(north,"shared-status@example.test","correct-password","INACTIVE",0,null);
        UUID other=user(south,"shared-status@example.test","correct-password","ACTIVE",0,null);
        UUID manager=user(north,"manager@example.test","correct-password","ACTIVE",0,null);
        migrate(null);
        // Model a verified shared identity; historical duplicates are never linked by migration.
        db.sql("update users set identity_id=? where id=?").params(member,other).update();
        db.sql("update tenant_memberships set identity_id=? where user_id=?").params(member,other).update();
        db.sql("update identity_accounts set status='ACTIVE' where id=?").param(member).update();
        var principal=new IdentityPrincipal(manager,north,"v34-north",Set.of(),Set.of());
        var controller=new UserController(db,new IdentityAccountService(db,passwords));
        var loader=new IdentityPrincipalLoader(db);
        ReflectionTestUtils.invokeMethod(controller,"status",principal,member,new UserController.Status("ACTIVE"));
        assertThat(loader.load(member,north)).isPresent();
        ReflectionTestUtils.invokeMethod(controller,"status",principal,member,new UserController.Status("INACTIVE"));
        assertThat(loader.load(member,north)).isEmpty();
        assertThat(loader.load(other,south)).isPresent();
        assertThatThrownBy(() -> ReflectionTestUtils.invokeMethod(controller,"status",principal,other,new UserController.Status("INACTIVE")))
            .isInstanceOf(ApiException.class);
        assertThat(loader.load(other,south)).isPresent();
        db.sql("update identity_accounts set status='INACTIVE' where id=?").param(member).update();
        ReflectionTestUtils.invokeMethod(controller,"status",principal,member,new UserController.Status("ACTIVE"));
        assertThat(db.sql("select status from identity_accounts where id=?").param(member).query(String.class).single()).isEqualTo("INACTIVE");
        assertThat(loader.load(member,north)).isEmpty();
    }
}
