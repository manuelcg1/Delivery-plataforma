package com.delivery.platform.merchant.application;

import com.delivery.platform.common.ApiException;
import com.delivery.platform.identity.auth.application.IdentityAccountService;
import com.delivery.platform.identity.security.IdentityPrincipal;
import com.delivery.platform.merchant.api.MerchantPortalAccount;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.nio.charset.StandardCharsets;
import java.util.UUID;

@Service
public class MerchantAccountProvisioner {
    private final JdbcClient db;
    private final IdentityAccountService identities;

    public MerchantAccountProvisioner(JdbcClient db, IdentityAccountService identities) {
        this.db=db; this.identities=identities;
    }

    @Transactional
    public void provision(IdentityPrincipal actor, UUID merchant, MerchantPortalAccount account) {
        if (!actor.permissions().contains("IDENTITY_USERS_CREATE") || !actor.permissions().contains("IDENTITY_ROLES_ASSIGN"))
            throw new ApiException(HttpStatus.FORBIDDEN,"MERCHANT_ACCOUNT_FORBIDDEN","Necesitas permisos para crear usuarios y asignar roles.");
        if (account.password()==null || account.password().length()<10 || account.password().getBytes(StandardCharsets.UTF_8).length>72)
            throw new ApiException(HttpStatus.BAD_REQUEST,"INVALID_PASSWORD","La contraseña debe tener al menos 10 caracteres y no superar 72 bytes.");
        if (db.sql("select count(*) from merchants where id=? and tenant_id=?").params(merchant,actor.tenantId()).query(Integer.class).single()!=1)
            throw new ApiException(HttpStatus.NOT_FOUND,"MERCHANT_NOT_FOUND","Comercio no encontrado");
        UUID role=db.sql("select id from roles where tenant_id=? and code='MERCHANT_PORTAL_OPERATOR' and active")
                .param(actor.tenantId()).query(UUID.class).optional().orElseThrow(()->new ApiException(HttpStatus.CONFLICT,
                        "MERCHANT_ROLE_MISSING","El rol de acceso al portal no está configurado o está inactivo."));
        IdentityAccountService.Account identity;
        try {
            identity=identities.createForManagedUser(account.email(),account.password());
        } catch (org.springframework.dao.DataIntegrityViolationException exception) {
            // A concurrent registration must not overwrite an identity or expose database details.
            throw new ApiException(HttpStatus.CONFLICT,"IDENTITY_EXISTS","El correo ya tiene una cuenta. Usa otro correo para crear un acceso nuevo.");
        }
        UUID user=UUID.randomUUID(), membership=UUID.randomUUID();
        db.sql("""
                insert into users(id,tenant_id,identity_id,email,password_hash,first_name,last_name,status)
                values(?,?,?,?,?,?,?,'ACTIVE')
                """).params(user,actor.tenantId(),identity.id(),identity.email(),identity.passwordHash(),account.firstName().trim(),account.lastName().trim()).update();
        db.sql("insert into tenant_memberships(identity_id,tenant_id,user_id) values(?,?,?)")
                .params(identity.id(),actor.tenantId(),user).update();
        db.sql("insert into user_roles(user_id,role_id) values(?,?)").params(user,role).update();
        db.sql("insert into merchant_memberships(id,tenant_id,merchant_id,user_id,role_code) values(?,?,?,?,'OWNER')")
                .params(membership,actor.tenantId(),merchant,user).update();
        db.sql("""
                insert into merchant_branch_assignments(tenant_id,membership_id,branch_id)
                select tenant_id,?,id from branches where tenant_id=? and merchant_id=?
                on conflict do nothing
                """).params(membership,actor.tenantId(),merchant).update();
    }
}
