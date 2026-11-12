package com.delivery.platform.identity.auth.application;
import com.delivery.platform.common.ApiException; import com.delivery.platform.identity.auth.api.AuthDtos.*; import com.delivery.platform.identity.security.*;
import org.springframework.beans.factory.annotation.*; import org.springframework.http.HttpStatus; import org.springframework.jdbc.core.simple.JdbcClient; import org.springframework.mail.javamail.JavaMailSender; import org.springframework.mail.SimpleMailMessage; import org.springframework.security.crypto.password.PasswordEncoder; import org.springframework.stereotype.Service; import org.springframework.transaction.annotation.Transactional;
import java.nio.charset.StandardCharsets; import java.security.*; import java.time.*; import java.util.*; import java.util.HexFormat;
@Service public class AuthService {
 static final String GRANT_ALL_PERMISSIONS_SQL =
  "insert into role_permissions(role_id,permission_id) select :r,id from permissions where module <> 'PLATFORM' on conflict do nothing";
 private final JdbcClient db; private final PasswordEncoder passwords; private final JwtService jwt; private final JavaMailSender mail; private final IdentityPrincipalLoader principalLoader; private final IdentityAccountService identityAccounts; private final SecureRandom random=new SecureRandom();
 @Value("${MAIL_FROM:notifications@example.test}") String mailFrom;
 @Value("${MOBILE_TENANT_CODE:}") String mobileTenantCode;
 @Value("${identity.refresh-days}")long refreshDays; @Value("${identity.reset-minutes}")long resetMinutes; @Value("${identity.frontend-url}")String frontendUrl; @Value("${identity.login-max-attempts}")int maxAttempts; @Value("${identity.login-lock-minutes}")long lockMinutes;
 public AuthService(JdbcClient db,PasswordEncoder passwords,JwtService jwt,JavaMailSender mail,IdentityPrincipalLoader principalLoader,IdentityAccountService identityAccounts){this.db=db;this.passwords=passwords;this.jwt=jwt;this.mail=mail;this.principalLoader=principalLoader;this.identityAccounts=identityAccounts;}
 record UserRow(UUID id,UUID identityId,UUID tenantId,String tenantCode,String tenantName,String email,String passwordHash,String firstName,String lastName,String userStatus,String identityStatus,String tenantStatus,int attempts,Instant lockedUntil,boolean mustChangePassword){}
 @Transactional public Session register(RegisterTenant q,String ip,String agent){if(db.sql("select count(*) from tenants where code=:c").param("c",q.tenantCode()).query(Integer.class).single()>0)throw new ApiException(HttpStatus.CONFLICT,"TENANT_CODE_EXISTS","El código de empresa ya está registrado");String email=q.adminEmail().trim().toLowerCase();IdentityAccountService.Account identity=identityAccounts.verifyOrCreate(email,q.adminPassword());UUID t=UUID.randomUUID(),u=UUID.randomUUID(),r=UUID.randomUUID();db.sql("insert into tenants(id,code,name,status) values(:id,:c,:n,'ACTIVE')").param("id",t).param("c",q.tenantCode()).param("n",q.tenantName()).update();db.sql("insert into users(id,tenant_id,identity_id,email,password_hash,first_name,last_name,status) values(:id,:t,:identity,:e,:p,:f,:l,'ACTIVE')").param("id",u).param("t",t).param("identity",identity.id()).param("e",email).param("p",identity.passwordHash()).param("f",q.adminFirstName()).param("l",q.adminLastName()).update();linkMembership(u,t,identity.id());db.sql("insert into roles(id,tenant_id,code,name,description,system_role) values(:id,:t,'TENANT_ADMIN','Administrador del tenant','Administración completa',true)").param("id",r).param("t",t).update();db.sql(GRANT_ALL_PERMISSIONS_SQL).param("r",r).update();db.sql("insert into user_roles values(:u,:r)").param("u",u).param("r",r).update();audit(t,u,"TENANT_REGISTERED","TENANT",t,ip,agent);return session(load(u),ip,agent);}
 @Transactional public Session registerCustomer(RegisterCustomer q,String ip,String agent){UUID tenant=db.sql("select id from tenants where code=:code and status='ACTIVE'").param("code",q.tenantCode()).query(UUID.class).optional().orElseThrow(()->new ApiException(HttpStatus.NOT_FOUND,"TENANT_NOT_FOUND","Empresa no encontrada"));String email=q.email().trim().toLowerCase();if(db.sql("select count(*) from users where tenant_id=:tenant and lower(email)=:email").param("tenant",tenant).param("email",email).query(Integer.class).single()>0)throw new ApiException(HttpStatus.CONFLICT,"EMAIL_EXISTS","El correo ya está registrado en esta empresa");IdentityAccountService.Account identity=identityAccounts.verifyOrCreate(email,q.password());UUID user=UUID.randomUUID();db.sql("insert into users(id,tenant_id,identity_id,email,password_hash,first_name,last_name,status) values(:id,:tenant,:identity,:email,:password,:first,:last,'ACTIVE')").param("id",user).param("tenant",tenant).param("identity",identity.id()).param("email",email).param("password",identity.passwordHash()).param("first",q.firstName().trim()).param("last",q.lastName().trim()).update();linkMembership(user,tenant,identity.id());int assigned=db.sql("insert into user_roles(user_id,role_id) select :user,id from roles where tenant_id=:tenant and code='CUSTOMER' and active on conflict do nothing").param("user",user).param("tenant",tenant).update();if(assigned==0)throw new ApiException(HttpStatus.CONFLICT,"CUSTOMER_ROLE_MISSING","El rol de cliente no está configurado");audit(tenant,user,"CUSTOMER_REGISTERED","USER",user,ip,agent);return session(load(user),ip,agent);}
 @Transactional(noRollbackFor=ApiException.class) public Session loginMobile(Login q,String ip,String agent){
   String code=mobileTenantCode();
   return authenticate(new Login(q.email(),q.password(),code),ip,agent,true);
 }
 @Transactional(noRollbackFor=ApiException.class) public Session login(Login q,String ip,String agent){return authenticate(q,ip,agent,false);}
 private Session authenticate(Login q,String ip,String agent,boolean mobile){UserRow u=findLogin(q.tenantCode(),q.email());if(!"ACTIVE".equals(u.tenantStatus())||"INACTIVE".equals(u.userStatus())||"INACTIVE".equals(u.identityStatus()))throw invalid();if(u.lockedUntil()!=null&&u.lockedUntil().isAfter(Instant.now()))throw new ApiException(HttpStatus.LOCKED,"ACCOUNT_LOCKED","La cuenta está temporalmente bloqueada");if(!passwords.matches(q.password(),u.passwordHash())){db.sql("update identity_accounts set failed_login_attempts=failed_login_attempts+1,locked_until=case when failed_login_attempts+1>=:max then now()+make_interval(mins=>cast(:minutes as integer)) else null end,status=case when failed_login_attempts+1>=:max then 'LOCKED' else status end,updated_at=now() where id=:identity").param("max",maxAttempts).param("minutes",lockMinutes).param("identity",u.identityId()).update();audit(u.tenantId(),u.id(),"LOGIN_FAILED",null,null,ip,agent);throw invalid();}ensureCourierActive(u);db.sql("update identity_accounts set failed_login_attempts=0,locked_until=null,status='ACTIVE',last_tenant_id=:tenant,updated_at=now() where id=:identity").param("identity",u.identityId()).param("tenant",u.tenantId()).update();db.sql("update users set status=case when status='LOCKED' then 'ACTIVE' else status end,last_login_at=now() where id=:id").param("id",u.id()).update();audit(u.tenantId(),u.id(),"LOGIN_SUCCESS",null,null,ip,agent);return session(load(u.id()),ip,agent);}
 static String normalizeMobilePhone(String raw){
   String phone=raw==null?"":raw.replaceAll("[\\s()\\-]", "");
   if(phone.matches("9[0-9]{8}"))return "+51"+phone;
   if(phone.matches("\\+519[0-9]{8}"))return phone;
   throw new ApiException(HttpStatus.BAD_REQUEST,"INVALID_PHONE","Ingresa un celular peruano de 9 dígitos que empiece en 9");
 }
 private String mobileTenantCode(){
   if(mobileTenantCode==null||mobileTenantCode.isBlank())throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE,"MOBILE_TENANT_UNAVAILABLE","El acceso móvil no está configurado");
   String code=mobileTenantCode.trim();
   if(!db.sql("select exists(select 1 from tenants where code=:code and status='ACTIVE')").param("code",code).query(Boolean.class).single())
     throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE,"MOBILE_TENANT_UNAVAILABLE","El acceso móvil no está disponible");
   return code;
 }
 private void ensureCourierActive(UserRow user){
   boolean pending=db.sql("""
       select exists(select 1 from user_roles ur join roles r on r.id=ur.role_id
         where ur.user_id=:user and r.tenant_id=:tenant and r.code='COURIER' and r.active
         and not exists(select 1 from user_roles admins join roles ar on ar.id=admins.role_id
           where admins.user_id=:user and ar.active and (ar.tenant_id=:tenant or ar.tenant_id is null)
             and ar.code in ('TENANT_ADMIN','PLATFORM_ADMIN','PLATFORM_OWNER','ROLE_PLATFORM_OWNER'))
         and not exists(select 1 from courier_profiles cp where cp.user_id=:user
           and cp.tenant_id=:tenant and cp.status='ACTIVE'))
       """).param("user",user.id()).param("tenant",user.tenantId()).query(Boolean.class).single();
   if(pending)throw new ApiException(HttpStatus.FORBIDDEN,"COURIER_PENDING_APPROVAL",PENDING_MESSAGE);
 }
 private static final String PENDING_MESSAGE="Tu cuenta de repartidor está pendiente de activación por el administrador.";
 @Transactional public Object registerMobile(RegisterMobile q,String ip,String agent){
   String code=mobileTenantCode(), phone=normalizeMobilePhone(q.phone());
   if(q.profile()==null)throw new ApiException(HttpStatus.BAD_REQUEST,"INVALID_PROFILE","Elige Cliente o Repartidor");
   UUID tenant=db.sql("select id from tenants where code=:code and status='ACTIVE'").param("code",code).query(UUID.class).single();
   String email=q.email().trim().toLowerCase(Locale.ROOT);
   if(db.sql("select exists(select 1 from users where tenant_id=:tenant and lower(email)=:email)").param("tenant",tenant).param("email",email).query(Boolean.class).single())
     throw new ApiException(HttpStatus.CONFLICT,"EMAIL_EXISTS","El correo ya está registrado en esta empresa");
   IdentityAccountService.Account identity=identityAccounts.verifyOrCreate(email,q.password());
   UUID user=UUID.randomUUID();
   db.sql("""
       insert into users(id,tenant_id,identity_id,email,password_hash,first_name,last_name,phone,status)
       values(:id,:tenant,:identity,:email,:password,:first,:last,:phone,'ACTIVE')
       """).param("id",user).param("tenant",tenant).param("identity",identity.id()).param("email",email)
       .param("password",identity.passwordHash()).param("first",q.firstName().trim()).param("last",q.lastName().trim()).param("phone",phone).update();
   linkMembership(user,tenant,identity.id());
   int assigned=db.sql("insert into user_roles(user_id,role_id) select :user,id from roles where tenant_id=:tenant and code=:role and active")
       .param("user",user).param("tenant",tenant).param("role",q.profile().name()).update();
   if(assigned!=1)throw new ApiException(HttpStatus.CONFLICT,"MOBILE_ROLE_MISSING","El perfil solicitado no está configurado");
   if(q.profile()==MobileProfile.COURIER){
     db.sql("insert into courier_profiles(tenant_id,user_id,status,vehicle_type,phone) values(:tenant,:user,'INACTIVE','OTHER',:phone)")
       .param("tenant",tenant).param("user",user).param("phone",phone).update();
     audit(tenant,user,"COURIER_REGISTERED","USER",user,ip,agent);
     return new PendingApproval(true,PENDING_MESSAGE);
   }
   audit(tenant,user,"CUSTOMER_REGISTERED","USER",user,ip,agent);
   return session(load(user),ip,agent);
 }
 @Transactional public Session refresh(String raw,String ip,String agent){if(raw==null||raw.isBlank())throw token();String tokenHash=hash(raw);Object[] token=db.sql("select user_id,context_tenant_id from refresh_tokens where token_hash=:h and revoked_at is null and expires_at>now() for update").param("h",tokenHash).query((row,index)->new Object[]{row.getObject(1,UUID.class),row.getObject(2,UUID.class)}).optional().orElseThrow(this::token);UserRow current=load((UUID)token[0]);UUID context=(UUID)token[1];if(!"ACTIVE".equals(current.userStatus())||!"ACTIVE".equals(current.identityStatus())||principalLoader.load(current.id(),context).isEmpty())throw token();ensureCourierActive(current);db.sql("update refresh_tokens set revoked_at=now() where token_hash=:h").param("h",tokenHash).update();return session(current,context,ip,agent,true,null);}
 @Transactional public Session switchContext(IdentityPrincipal current,String tenantCode,String rawRefresh,String ip,String agent){if(!current.roles().contains("ROLE_PLATFORM_OWNER"))throw new ApiException(HttpStatus.FORBIDDEN,"CONTEXT_SWITCH_FORBIDDEN","Solo el propietario de plataforma puede cambiar el contexto operativo.");if(rawRefresh==null||rawRefresh.isBlank())throw token();UUID tenant=db.sql("select id from tenants where code=:code and status='ACTIVE'").param("code",tenantCode.trim()).query(UUID.class).optional().orElseThrow(()->new ApiException(HttpStatus.NOT_FOUND,"TENANT_NOT_FOUND","Empresa no encontrada"));principalLoader.load(current.userId(),tenant).orElseThrow(this::token);String tokenHash=hash(rawRefresh);int updated=db.sql("update refresh_tokens set context_tenant_id=:tenant where token_hash=:hash and user_id=:user and revoked_at is null and expires_at>now()").param("tenant",tenant).param("hash",tokenHash).param("user",current.userId()).update();if(updated!=1)throw token();UserRow owner=load(current.userId());db.sql("update identity_accounts set last_tenant_id=:tenant,updated_at=now() where id=:identity").param("tenant",tenant).param("identity",owner.identityId()).update();db.sql("insert into audit_logs(tenant_id,user_id,action,entity_type,entity_id,ip_address,user_agent,metadata) values(:tenant,:user,'PLATFORM_TENANT_CONTEXT_SELECTED','TENANT',:tenant,:ip,:agent,jsonb_build_object('tenantCode',:code))").param("tenant",tenant).param("user",current.userId()).param("ip",ip).param("agent",agent).param("code",tenantCode.trim()).update();return session(owner,tenant,ip,agent,false,rawRefresh);}
 @Transactional public void logout(String raw,IdentityPrincipal p,String ip,String agent){if(raw!=null)db.sql("update refresh_tokens set revoked_at=now() where token_hash=:h and user_id=:u").param("h",hash(raw)).param("u",p.userId()).update();audit(p.tenantId(),p.userId(),"LOGOUT",null,null,ip,agent);}
 SimpleMailMessage resetMessage(String recipient,String token) {
  var message=new SimpleMailMessage();
  message.setFrom(mailFrom);
  message.setTo(recipient);
  message.setSubject("Restablecer contraseña");
  message.setText("Abre este enlace para restablecer tu contraseña: "+frontendUrl+"/reset-password?token="+token);
  return message;
 }
 @Transactional public void forgot(Forgot q,String ip,String agent){findOptional(q.tenantCode(),q.email()).ifPresent(u->{String raw=randomToken();db.sql("insert into password_reset_tokens(user_id,token_hash,expires_at) values(:u,:h,:x)").param("u",u.id()).param("h",hash(raw)).param("x",OffsetDateTime.now(ZoneOffset.UTC).plusMinutes(resetMinutes)).update();audit(u.tenantId(),u.id(),"PASSWORD_RESET_REQUESTED",null,null,ip,agent);try{var m=resetMessage(u.email(),raw);mail.send(m);}catch(Exception ignored){}});}
 @Transactional public void reset(Reset q,String ip,String agent){UUID user=db.sql("select user_id from password_reset_tokens where token_hash=:h and used_at is null and expires_at>now() for update").param("h",hash(q.token())).query(UUID.class).optional().orElseThrow(this::token);db.sql("update password_reset_tokens set used_at=now() where token_hash=:h").param("h",hash(q.token())).update();UUID identity=db.sql("select identity_id from users where id=:user").param("user",user).query(UUID.class).single();String encoded=passwords.encode(q.newPassword());db.sql("update identity_accounts set password_hash=:password,failed_login_attempts=0,locked_until=null,status=case when status='LOCKED' then 'ACTIVE' else status end,updated_at=now() where id=:identity").param("password",encoded).param("identity",identity).update();db.sql("update users set password_hash=:password,updated_at=now() where identity_id=:identity").param("password",encoded).param("identity",identity).update();db.sql("update refresh_tokens set revoked_at=now() where user_id in(select id from users where identity_id=:identity) and revoked_at is null").param("identity",identity).update();var row=load(user);audit(row.tenantId(),user,"PASSWORD_RESET_COMPLETED",null,null,ip,agent);}
 @Transactional public void changePassword(IdentityPrincipal p,ChangePassword q,String ip,String agent){UserRow u=load(p.userId());if(!passwords.matches(q.currentPassword(),u.passwordHash()))throw new ApiException(HttpStatus.BAD_REQUEST,"CURRENT_PASSWORD_INVALID","La contraseña actual es incorrecta");if(passwords.matches(q.newPassword(),u.passwordHash()))throw new ApiException(HttpStatus.BAD_REQUEST,"PASSWORD_REUSED","La nueva contraseña debe ser diferente");String encoded=passwords.encode(q.newPassword());db.sql("update identity_accounts set password_hash=:password,updated_at=now() where id=:identity").param("password",encoded).param("identity",u.identityId()).update();db.sql("update users set password_hash=:password,must_change_password=false,updated_at=now() where identity_id=:identity").param("password",encoded).param("identity",u.identityId()).update();audit(p.tenantId(),p.userId(),"PASSWORD_CHANGED","USER",p.userId(),ip,agent);}
 public Me me(IdentityPrincipal p){UserRow user=load(p.userId());Tenant tenant=db.sql("select id,code,name from tenants where id=:tenant").param("tenant",p.tenantId()).query((row,index)->new Tenant(row.getObject("id",UUID.class),row.getString("code"),row.getString("name"))).single();return new Me(user.id(),tenant,user.firstName(),user.lastName(),user.email(),p.roles(),p.permissions(),user.mustChangePassword());}
 public record Session(Tokens response,String refreshToken){}
 private Session session(UserRow u,String ip,String agent){return session(u,u.tenantId(),ip,agent,true,null);}
 private Session session(UserRow u,UUID contextTenant,String ip,String agent,boolean createRefresh,String existingRefresh){IdentityPrincipal principal=principalLoader.load(u.id(),contextTenant).orElseThrow(this::token);Tenant tenant=db.sql("select id,code,name from tenants where id=:tenant and status='ACTIVE'").param("tenant",contextTenant).query((row,index)->new Tenant(row.getObject("id",UUID.class),row.getString("code"),row.getString("name"))).optional().orElseThrow(this::token);Me me=new Me(u.id(),tenant,u.firstName(),u.lastName(),u.email(),principal.roles(),principal.permissions(),u.mustChangePassword());String raw=existingRefresh;if(createRefresh){raw=randomToken();db.sql("insert into refresh_tokens(user_id,context_tenant_id,token_hash,expires_at,created_ip,user_agent) values(:u,:tenant,:h,:x,:ip,:a)").param("u",u.id()).param("tenant",contextTenant).param("h",hash(raw)).param("x",OffsetDateTime.now(ZoneOffset.UTC).plusDays(refreshDays)).param("ip",ip).param("a",agent).update();}db.sql("update identity_accounts set last_tenant_id=:tenant,updated_at=now() where id=:identity").param("tenant",contextTenant).param("identity",u.identityId()).update();return new Session(new Tokens(jwt.issue(principal),jwt.expiresIn(),me),raw);}
 private IdentityPrincipal principal(UserRow u){return principalLoader.load(u.id(),u.tenantId()).orElseThrow(this::token);}
 private Me toMe(UserRow u){var p=principal(u);return new Me(u.id(),new Tenant(u.tenantId(),u.tenantCode(),u.tenantName()),u.firstName(),u.lastName(),u.email(),p.roles(),p.permissions(),u.mustChangePassword());}
 private UserRow findLogin(String code,String email){
    String tenantCode=code==null||code.isBlank()?null:code.trim();
    List<UserRow> matches=db.sql("""
         select u.id,u.identity_id,u.tenant_id,t.code tenant_code,t.name tenant_name,
                        coalesce(i.email,i.legacy_email) email,i.password_hash,u.first_name,u.last_name,
                        u.status user_status,i.status identity_status,t.status tenant_status,
                        i.failed_login_attempts attempts,i.locked_until,u.must_change_password
         from tenant_memberships m join users u on u.id=m.user_id and u.identity_id=m.identity_id
         join identity_accounts i on i.id=m.identity_id join tenants t on t.id=m.tenant_id
         where m.active and u.status in ('ACTIVE','LOCKED')
            and (cast(:code as varchar) is null and (i.last_tenant_id=m.tenant_id or
                (not exists(select 1 from tenant_memberships previous where previous.identity_id=i.id
                    and previous.active and previous.tenant_id=i.last_tenant_id)
                 and (select count(*) from tenant_memberships options where options.identity_id=i.id and options.active)=1))
                 or t.code=:code)
             and (lower(i.email)=lower(:email) or lower(i.legacy_email)=lower(:email) or lower(u.username)=lower(:email))
         order by m.created_at
     """).param("code",tenantCode).param("email",email.trim()).query(UserRow.class).list();
    if(matches.isEmpty()){
        if(tenantCode==null&&db.sql("""
                select exists(select 1 from identity_accounts i
                  where (lower(i.email)=lower(:email) or lower(i.legacy_email)=lower(:email))
                    and (select count(*) from tenant_memberships m where m.identity_id=i.id and m.active)>1)
                """).param("email",email.trim()).query(Boolean.class).single())
            throw new ApiException(HttpStatus.BAD_REQUEST,"TENANT_SELECTION_REQUIRED","Esta cuenta pertenece a varias empresas; indica el código de la empresa.");
        throw invalid();
    }
    if(matches.size()>1)throw new ApiException(HttpStatus.BAD_REQUEST,"TENANT_SELECTION_REQUIRED","Hay más de una cuenta con esos datos; indica el código de empresa.");
    return matches.getFirst();
 }
 private Optional<UserRow> findOptional(String code,String email){return db.sql("select u.id,u.identity_id,u.tenant_id,t.code tenant_code,t.name tenant_name,coalesce(i.email,i.legacy_email) email,i.password_hash,u.first_name,u.last_name,u.status user_status,i.status identity_status,t.status tenant_status,i.failed_login_attempts attempts,i.locked_until,u.must_change_password from tenant_memberships m join users u on u.id=m.user_id join identity_accounts i on i.id=m.identity_id join tenants t on t.id=m.tenant_id where m.active and t.code=:c and (lower(i.email)=lower(:e) or lower(i.legacy_email)=lower(:e) or lower(u.username)=lower(:e))").param("c",code).param("e",email).query(UserRow.class).optional();}
 private UserRow load(UUID id){return db.sql("select u.id,u.identity_id,u.tenant_id,t.code tenant_code,t.name tenant_name,coalesce(i.email,i.legacy_email) email,i.password_hash,u.first_name,u.last_name,u.status user_status,i.status identity_status,t.status tenant_status,i.failed_login_attempts attempts,i.locked_until,u.must_change_password from users u join identity_accounts i on i.id=u.identity_id join tenants t on t.id=u.tenant_id where u.id=:id").param("id",id).query(UserRow.class).single();}
 private void linkMembership(UUID user,UUID tenant,UUID identity){db.sql("insert into tenant_memberships(identity_id,tenant_id,user_id) values(:identity,:tenant,:user)").param("identity",identity).param("tenant",tenant).param("user",user).update();}
 private void audit(UUID t,UUID u,String action,String type,UUID entity,String ip,String agent){db.sql("insert into audit_logs(tenant_id,user_id,action,entity_type,entity_id,ip_address,user_agent) values(:t,:u,:a,:y,:e,:ip,:ag)").param("t",t).param("u",u).param("a",action).param("y",type).param("e",entity).param("ip",ip).param("ag",agent).update();}
 private String randomToken(){byte[]b=new byte[48];random.nextBytes(b);return Base64.getUrlEncoder().withoutPadding().encodeToString(b);} private String hash(String s){try{return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(s.getBytes(StandardCharsets.UTF_8)));}catch(Exception e){throw new IllegalStateException(e);}}
 private ApiException invalid(){return new ApiException(HttpStatus.UNAUTHORIZED,"INVALID_CREDENTIALS","Credenciales inválidas");} private ApiException token(){return new ApiException(HttpStatus.UNAUTHORIZED,"INVALID_TOKEN","Token inválido o expirado");}
}
