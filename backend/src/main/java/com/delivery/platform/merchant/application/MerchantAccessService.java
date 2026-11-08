package com.delivery.platform.merchant.application;

import com.delivery.platform.catalog.common.CatalogSupport;
import com.delivery.platform.common.ApiException;
import com.delivery.platform.identity.security.IdentityPrincipal;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.nio.charset.StandardCharsets;
import java.util.*;
import static com.delivery.platform.merchant.api.MerchantAccessDtos.*;

@Service
public class MerchantAccessService {
    private final JdbcClient db;
    private final CatalogSupport support;
    private final PasswordEncoder passwords;
    public MerchantAccessService(JdbcClient db, CatalogSupport support, PasswordEncoder passwords) {
        this.db=db; this.support=support; this.passwords=passwords;
    }
    private record Account(UUID id, UUID identity, String email, String firstName, String lastName, String hash) {}
    public List<Access> list(IdentityPrincipal actor, UUID merchant) {
        support.merchant(actor,merchant);
        return accounts(actor,merchant).stream().map(a -> dto(a,exclusive(a,actor.tenantId(),merchant))).toList();
    }
    private List<Account> accounts(IdentityPrincipal actor, UUID merchant) {
        return db.sql("""
            select u.id,u.identity_id,i.email,u.first_name,u.last_name,i.password_hash
            from users u join merchant_memberships mm on mm.user_id=u.id and mm.tenant_id=u.tenant_id
            join identity_accounts i on i.id=u.identity_id and i.status='ACTIVE' and not i.email_conflict
            join tenant_memberships tm on tm.user_id=u.id and tm.tenant_id=u.tenant_id and tm.identity_id=u.identity_id
            where mm.merchant_id=? and mm.tenant_id=? and mm.active and tm.active and u.status='ACTIVE'
            and mm.role_code in ('OWNER','MANAGER') order by u.email
            """).params(merchant,actor.tenantId()).query((r,n)->new Account(r.getObject("id",UUID.class),
                r.getObject("identity_id",UUID.class),r.getString("email"),r.getString("first_name"),
                r.getString("last_name"),r.getString("password_hash"))).list();
    }
    private boolean exclusive(Account account, UUID tenant, UUID merchant) {
        return db.sql("""
            select (select count(*) from tenant_memberships where identity_id=? and (tenant_id<>? or user_id<>?))
              + (select count(*) from users where identity_id=? and id<>?)
              + (select count(*) from merchant_memberships where user_id=? and (tenant_id<>? or merchant_id<>?))
              + (select count(*) from user_roles ur join roles r on r.id=ur.role_id
                 where ur.user_id=? and (r.tenant_id is null or r.tenant_id<>? or r.code not in ('MERCHANT_PORTAL_OPERATOR','MERCHANT_OPERATOR')))
            """).params(account.identity(),tenant,account.id(),account.identity(),account.id(),account.id(),tenant,
                merchant,account.id(),tenant).query(Integer.class).single()==0;
    }
    @Transactional
    public Access update(IdentityPrincipal actor, UUID merchant, UUID user, Update request) {
        support.merchant(actor,merchant);
        Account account=accounts(actor,merchant).stream().filter(a->a.id().equals(user)).findFirst()
            .orElseThrow(()->new ApiException(HttpStatus.NOT_FOUND,"PORTAL_ACCESS_NOT_FOUND","Acceso no encontrado"));
        db.sql("select id from identity_accounts where id=? for update").param(account.identity()).query(UUID.class).single();
        // Re-read after acquiring the identity lock so a blank password cannot restore
        // a stale hash after another administrator has changed the credentials.
        account=accounts(actor,merchant).stream().filter(a->a.id().equals(user)).findFirst()
            .orElseThrow(()->new ApiException(HttpStatus.NOT_FOUND,"PORTAL_ACCESS_NOT_FOUND","Acceso no encontrado"));
        if (!exclusive(account,actor.tenantId(),merchant))
            throw new ApiException(HttpStatus.CONFLICT,"SHARED_PORTAL_IDENTITY","Esta cuenta comparte otros accesos; sus credenciales deben administrarse desde identidad.");
        validatePassword(request.newPassword());
        String email=request.email().trim().toLowerCase(Locale.ROOT);
        if (db.sql("""
            select (select count(*) from identity_accounts where id<>? and (lower(email)=? or lower(legacy_email)=?))
              + (select count(*) from users where identity_id<>? and lower(email)=?)
            """).params(account.identity(),email,email,account.identity(),email).query(Integer.class).single()>0)
            throw duplicate();
        boolean changePassword=request.newPassword()!=null && !request.newPassword().isEmpty();
        String hash=changePassword?passwords.encode(request.newPassword()):account.hash();
        try {
            db.sql("update identity_accounts set email=?,legacy_email=?,email_conflict=false,password_hash=?,updated_at=now() where id=?")
                .params(email,email,hash,account.identity()).update();
            db.sql("update users set email=?,first_name=?,last_name=?,password_hash=?,updated_at=now() where id=? and tenant_id=? and identity_id=?")
                .params(email,request.firstName().trim(),request.lastName().trim(),hash,user,actor.tenantId(),account.identity()).update();
        } catch (DataIntegrityViolationException exception) { throw duplicate(); }
        if (changePassword || !email.equals(account.email()))
            db.sql("update refresh_tokens set revoked_at=now() where revoked_at is null and user_id in (select id from users where identity_id=?)")
                .param(account.identity()).update();
        support.audit(actor,"MERCHANT_ACCESS_UPDATED","MERCHANT",merchant);
        return new Access(user,email,request.firstName().trim(),request.lastName().trim(),true,null);
    }
    static void validatePassword(String password) {
        if (password!=null && !password.isEmpty() && (password.isBlank() || password.length()<10 || password.getBytes(StandardCharsets.UTF_8).length>72))
            throw new ApiException(HttpStatus.BAD_REQUEST,"INVALID_PASSWORD","La contraseña debe tener al menos 10 caracteres y no superar 72 bytes.");
    }
    private Access dto(Account a, boolean editable) { return new Access(a.id(),a.email(),a.firstName(),a.lastName(),editable,editable?null:"SHARED_PORTAL_IDENTITY"); }
    private ApiException duplicate() { return new ApiException(HttpStatus.CONFLICT,"IDENTITY_EXISTS","El correo ya tiene una cuenta."); }
}
