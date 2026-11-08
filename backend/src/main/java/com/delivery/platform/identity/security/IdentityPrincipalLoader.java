package com.delivery.platform.identity.security;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;

import java.util.HashSet;
import java.util.Optional;
import java.util.UUID;

@Component
public class IdentityPrincipalLoader {
    private final JdbcClient db;

    public IdentityPrincipalLoader(JdbcClient db) {
        this.db = db;
    }

    public Optional<IdentityPrincipal> load(UUID userId, UUID claimedTenantId) {
        IdentityPrincipal scope = db.sql("""
                                                                select u.tenant_id,t.code
                                                                from users u
                                                                join identity_accounts i on i.id=u.identity_id and i.status='ACTIVE'
                                                                join tenant_memberships m on m.user_id=u.id and m.identity_id=i.id and m.active
                                                                join tenants t on t.id=u.tenant_id
                where u.id=:user and u.tenant_id=:tenant
                  and u.status='ACTIVE' and t.status='ACTIVE'
                """)
                .param("user", userId).param("tenant", claimedTenantId)
                .query((row, index) -> new IdentityPrincipal(userId,
                        row.getObject("tenant_id", UUID.class), row.getString("code"),
                        new HashSet<>(), new HashSet<>()))
                .optional().orElse(null);
        if (scope == null) return loadPlatformOwnerContext(userId, claimedTenantId);

        var roles = new HashSet<>(db.sql("""
                select r.code from roles r join user_roles ur on ur.role_id=r.id
                where ur.user_id=:user and r.active and (r.tenant_id=:tenant or r.tenant_id is null)
                """)
                .param("user", userId).param("tenant", claimedTenantId)
                .query(String.class).list());
        var permissions = new HashSet<>(db.sql("""
                select distinct p.code from permissions p
                join role_permissions rp on rp.permission_id=p.id
                join roles r on r.id=rp.role_id
                join user_roles ur on ur.role_id=r.id
                where ur.user_id=:user and r.active
                  and (r.tenant_id=:tenant or r.tenant_id is null)
                """)
                .param("user", userId).param("tenant", claimedTenantId)
                .query(String.class).list());
        return Optional.of(new IdentityPrincipal(userId, scope.tenantId(), scope.tenantCode(), roles, permissions));
    }

    private Optional<IdentityPrincipal> loadPlatformOwnerContext(UUID userId, UUID tenantId) {
        IdentityPrincipal platformIdentity = db.sql("""
                select t.id,t.code
                from users u
                join identity_accounts i on i.id=u.identity_id and i.status='ACTIVE'
                join tenants home on home.id=u.tenant_id and home.code='platform'
                join user_roles ur on ur.user_id=u.id
                join roles owner_role on owner_role.id=ur.role_id and owner_role.code='ROLE_PLATFORM_OWNER'
                    and owner_role.tenant_id is null and owner_role.active
                join tenants t on t.id=:tenant and t.status='ACTIVE' and t.code<>'platform'
                where u.id=:user and u.status='ACTIVE'
                """)
                .param("user", userId).param("tenant", tenantId)
                .query((row, index) -> new IdentityPrincipal(userId,
                        row.getObject("id", UUID.class), row.getString("code"),
                        new HashSet<>(), new HashSet<>()))
                .optional().orElse(null);
        if (platformIdentity == null) return Optional.empty();

        var roles = new HashSet<>(db.sql("""
                select r.code from user_roles ur join roles r on r.id=ur.role_id
                where ur.user_id=:user and r.tenant_id is null and r.active
                union
                select 'TENANT_ADMIN' from roles r
                where r.tenant_id=:tenant and r.code='TENANT_ADMIN' and r.active
                """)
                .param("user", userId).param("tenant", tenantId).query(String.class).list());
        var permissions = new HashSet<>(db.sql("""
                select distinct p.code from user_roles ur
                join roles r on r.id=ur.role_id and r.tenant_id is null and r.active
                join role_permissions rp on rp.role_id=r.id
                join permissions p on p.id=rp.permission_id
                where ur.user_id=:user
                union
                select distinct p.code from roles r
                join role_permissions rp on rp.role_id=r.id
                join permissions p on p.id=rp.permission_id
                where r.tenant_id=:tenant and r.code='TENANT_ADMIN' and r.active
                """)
                .param("user", userId).param("tenant", tenantId).query(String.class).list());
        return Optional.of(new IdentityPrincipal(userId, platformIdentity.tenantId(),
                platformIdentity.tenantCode(), roles, permissions));
    }
}