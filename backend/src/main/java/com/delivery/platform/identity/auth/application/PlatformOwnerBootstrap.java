package com.delivery.platform.identity.auth.application;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

@Component
@ConditionalOnProperty(name = "platform.owner.bootstrap-enabled", havingValue = "true")
public class PlatformOwnerBootstrap {
    private static final Logger log = LoggerFactory.getLogger(PlatformOwnerBootstrap.class);

    private final JdbcClient db;
    private final PasswordEncoder passwords;
    private final String initialPassword;
    private final String email;
    private final String username;

    public PlatformOwnerBootstrap(
            JdbcClient db,
            PasswordEncoder passwords,
            @Value("${platform.owner.initial-password:}") String initialPassword,
            @Value("${platform.owner.email:}") String email,
            @Value("${platform.owner.username:platform_owner}") String username) {
        this.db = db;
        this.passwords = passwords;
        this.initialPassword = initialPassword;
        this.email = email.trim().toLowerCase();
        this.username = username.trim().toLowerCase();
    }

    @EventListener(ApplicationReadyEvent.class)
    @Transactional
    public void ensureOwner() {
        if (email.isBlank()) {
            throw new IllegalStateException("PLATFORM_OWNER_EMAIL is required when owner bootstrap is enabled");
        }
        UUID roleId = db.sql("select id from roles where tenant_id is null and code='ROLE_PLATFORM_OWNER'")
                .query(UUID.class).single();
        db.sql("insert into role_permissions(role_id,permission_id) select :role,id from permissions on conflict do nothing")
                .param("role", roleId).update();

        UUID existing = db.sql("""
                select u.id from users u join tenants t on t.id=u.tenant_id
                where t.code='platform' and (lower(u.email)=:email or lower(u.username)=:username)
                order by u.created_at limit 1
                """)
                .param("email", email).param("username", username).query(UUID.class).optional().orElse(null);
        if (existing != null) {
            db.sql("insert into user_roles(user_id,role_id) values(:user,:role) on conflict do nothing")
                    .param("user", existing).param("role", roleId).update();
            return;
        }
        if (initialPassword.isBlank()) {
            log.warn("Platform Owner is not provisioned: PLATFORM_OWNER_INITIAL_PASSWORD is not configured");
            return;
        }

        UUID tenantId = db.sql("select id from tenants where code='platform'").query(UUID.class).single();
        UUID userId = UUID.randomUUID();
        db.sql("""
                insert into users(id,tenant_id,email,username,password_hash,first_name,last_name,status,
                                  email_verified,must_change_password)
                values(:id,:tenant,:email,:username,:password,'Platform','Owner','ACTIVE',true,true)
                """)
                .param("id", userId).param("tenant", tenantId).param("email", email)
                .param("username", username).param("password", passwords.encode(initialPassword)).update();
        db.sql("insert into user_roles(user_id,role_id) values(:user,:role)")
                .param("user", userId).param("role", roleId).update();
        db.sql("""
                insert into audit_logs(tenant_id,user_id,action,entity_type,entity_id,metadata)
                values(:tenant,:user,'PLATFORM_OWNER_CREATED','USER',:user,
                       jsonb_build_object('username',:username,'source','bootstrap'))
                """)
                .param("tenant", tenantId).param("user", userId).param("username", username).update();
        log.info("Platform Owner provisioned for {}", email);
    }
}
