package com.delivery.platform.identity.auth.application;

import com.delivery.platform.common.ApiException;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Locale;
import java.util.UUID;

@Service
public class IdentityAccountService {
    public record Account(UUID id, String email, String passwordHash) {}

    private final JdbcClient db;
    private final PasswordEncoder passwords;

    public IdentityAccountService(JdbcClient db, PasswordEncoder passwords) {
        this.db = db;
        this.passwords = passwords;
    }

    @Transactional
    public Account verifyOrCreate(String rawEmail, String rawPassword) {
        String email = normalize(rawEmail);
        Account existing = find(email);
        if (existing != null) {
            if (!passwords.matches(rawPassword, existing.passwordHash())) {
                throw new ApiException(HttpStatus.CONFLICT, "IDENTITY_CREDENTIALS_REQUIRED",
                        "Ese correo ya tiene una cuenta; autentícate con su contraseña para vincular la empresa.");
            }
            return existing;
        }
        rejectUnresolvedLegacyCollision(email);
        return insert(email, passwords.encode(rawPassword));
    }

    @Transactional
    public Account createForManagedUser(String rawEmail, String rawPassword) {
        String email = normalize(rawEmail);
        if (find(email) != null) {
            throw new ApiException(HttpStatus.CONFLICT, "IDENTITY_EXISTS",
                    "La identidad ya existe; debe vincularse mediante un flujo de invitación verificado.");
        }
        rejectUnresolvedLegacyCollision(email);
        return insert(email, passwords.encode(rawPassword));
    }

    @Transactional
    public void synchronizeMembershipStatus(UUID userId, UUID tenantId, String status) {
        boolean active = "ACTIVE".equals(status);
        db.sql("""
                update tenant_memberships m set active=:active,updated_at=now()
                where m.user_id=:user and m.tenant_id=:tenant
                  and exists(select 1 from users u where u.id=m.user_id
                    and u.tenant_id=m.tenant_id and u.identity_id=m.identity_id)
                """).param("active", active).param("user", userId).param("tenant", tenantId).update();
        if (active) {
            // V34 copies a legacy user's suspension into its exclusive identity.
            // A tenant administrator must never lift a shared identity's global suspension.
            db.sql("""
                    update identity_accounts i set status='ACTIVE',locked_until=null,
                        failed_login_attempts=0,updated_at=now()
                    where i.id=:user and i.status in ('INACTIVE','LOCKED')
                      and exists(select 1 from users u where u.id=:user
                        and u.identity_id=i.id and u.tenant_id=:tenant)
                      and not exists(select 1 from tenant_memberships m
                        where m.identity_id=i.id and m.tenant_id<>:tenant)
                    """).param("user", userId).param("tenant", tenantId).update();
        }
    }

    private Account find(String email) {
        return db.sql("""
                select id,email,password_hash from identity_accounts
                where lower(email)=:email and status='ACTIVE' and not email_conflict
                """)
                .param("email", email)
                .query((row, index) -> new Account(row.getObject("id", UUID.class),
                        row.getString("email"), row.getString("password_hash")))
                .optional().orElse(null);
    }

    private Account insert(String email, String passwordHash) {
        UUID id = UUID.randomUUID();
        db.sql("""
            insert into identity_accounts(id,email,legacy_email,password_hash,status,email_conflict)
            values(:id,:email,:email,:password,'ACTIVE',false)
            """)
            .param("id", id).param("email", email).param("password", passwordHash).update();
        return new Account(id, email, passwordHash);
    }

        private void rejectUnresolvedLegacyCollision(String email) {
            boolean emailReserved = db.sql("select exists(select 1 from identity_accounts where lower(email)=:email)")
                .param("email", email).query(Boolean.class).single();
            if (emailReserved) {
                throw new ApiException(HttpStatus.CONFLICT, "IDENTITY_NOT_ACTIVE",
                    "La cuenta asociada a este correo no está activa.");
            }
                boolean unresolved = db.sql("""
                                select exists(select 1 from identity_accounts
                                    where lower(legacy_email)=:email and email_conflict)
                                """)
                                .param("email", email).query(Boolean.class).single();
                if (unresolved) {
                        throw new ApiException(HttpStatus.CONFLICT, "IDENTITY_EMAIL_CONFLICT",
                                        "El correo tiene cuentas históricas pendientes de vinculación segura.");
                }
        }

    private String normalize(String email) {
        if (email == null || email.isBlank()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "EMAIL_REQUIRED", "Ingresa el correo electrónico.");
        }
        return email.trim().toLowerCase(Locale.ROOT);
    }
}
