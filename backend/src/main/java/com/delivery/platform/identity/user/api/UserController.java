package com.delivery.platform.identity.user.api;

import com.delivery.platform.common.ApiException;
import com.delivery.platform.identity.security.IdentityPrincipal;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.util.*;

@RestController
@RequestMapping("/api/v1/users")
public class UserController {
    public record UserDto(UUID id, String email, String firstName, String lastName, String phone, String status, List<String> roles) {}
    public record Create(@Email @NotBlank String email, @Size(min=10) String password, @NotBlank String firstName,
                         @NotBlank String lastName, String phone, Set<UUID> roleIds) {}
    public record Update(@NotBlank String firstName, @NotBlank String lastName, String phone) {}
    public record Status(@Pattern(regexp="ACTIVE|INACTIVE|LOCKED") String status) {}
    public record Roles(Set<UUID> roleIds) {}

    private final JdbcClient db;
    private final PasswordEncoder encoder;

    public UserController(JdbcClient db, PasswordEncoder encoder) {
        this.db = db;
        this.encoder = encoder;
    }

    @GetMapping
    @PreAuthorize("hasAuthority('IDENTITY_USERS_VIEW')")
    List<UserDto> list(@AuthenticationPrincipal IdentityPrincipal principal,
                       @RequestParam(defaultValue="") String search,
                       @RequestParam(required=false) String status) {
        return db.sql("select u.id,u.email,u.first_name,u.last_name,u.phone,u.status from users u where u.tenant_id=:t and (:s='' or lower(u.email||' '||u.first_name||' '||u.last_name) like lower('%'||:s||'%')) and (cast(:st as varchar) is null or u.status=:st) order by u.created_at desc limit 100")
                .param("t", principal.tenantId()).param("s", search).param("st", status)
                .query((row, n) -> dto(row.getObject("id", UUID.class), row.getString("email"),
                        row.getString("first_name"), row.getString("last_name"), row.getString("phone"), row.getString("status"))).list();
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAuthority('IDENTITY_USERS_VIEW')")
    UserDto one(@AuthenticationPrincipal IdentityPrincipal principal, @PathVariable UUID id) {
        return db.sql("select id,email,first_name,last_name,phone,status from users where id=:id and tenant_id=:t")
                .param("id", id).param("t", principal.tenantId())
                .query((row, n) -> dto(id, row.getString("email"), row.getString("first_name"),
                        row.getString("last_name"), row.getString("phone"), row.getString("status")))
                .optional().orElseThrow(this::missing);
    }

    @PostMapping
    @Transactional
    @PreAuthorize("hasAuthority('IDENTITY_USERS_CREATE')")
    UserDto create(@AuthenticationPrincipal IdentityPrincipal principal, @Valid @RequestBody Create request) {
        if (request.roleIds()!=null && !request.roleIds().isEmpty() && !principal.permissions().contains("IDENTITY_ROLES_ASSIGN"))
            throw new ApiException(HttpStatus.FORBIDDEN, "ROLE_ASSIGN_FORBIDDEN", "No tienes permiso para asignar roles");
        UUID id = UUID.randomUUID();
        try {
            db.sql("insert into users(id,tenant_id,email,password_hash,first_name,last_name,phone,status) values(:id,:t,lower(:e),:pw,:f,:l,:ph,'ACTIVE')")
                    .param("id", id).param("t", principal.tenantId()).param("e", request.email())
                    .param("pw", encoder.encode(request.password())).param("f", request.firstName())
                    .param("l", request.lastName()).param("ph", request.phone()).update();
            assign(principal, id, request.roleIds());
            audit(principal, "USER_CREATED", id);
        } catch (org.springframework.dao.DataIntegrityViolationException exception) {
            throw new ApiException(HttpStatus.CONFLICT, "USER_EXISTS", "El correo ya está registrado");
        }
        return one(principal, id);
    }

    @PutMapping("/{id}")
    @Transactional
    @PreAuthorize("hasAuthority('IDENTITY_USERS_UPDATE')")
    UserDto update(@AuthenticationPrincipal IdentityPrincipal principal, @PathVariable UUID id,
                   @Valid @RequestBody Update request) {
        owned(principal, id);
        db.sql("update users set first_name=:f,last_name=:l,phone=:ph,updated_at=now() where id=:id and tenant_id=:t")
                .param("f", request.firstName()).param("l", request.lastName()).param("ph", request.phone()).param("id", id).param("t", principal.tenantId()).update();
        audit(principal, "USER_UPDATED", id);
        return one(principal, id);
    }

    @PatchMapping("/{id}/status")
    @Transactional
    @PreAuthorize("hasAuthority('IDENTITY_USERS_DISABLE')")
    UserDto status(@AuthenticationPrincipal IdentityPrincipal principal, @PathVariable UUID id,
                   @Valid @RequestBody Status request) {
        owned(principal, id);
        if (!"ACTIVE".equals(request.status()) && hasRole(id, "TENANT_ADMIN") && isLastAdmin(principal))
            throw new ApiException(HttpStatus.CONFLICT, "LAST_TENANT_ADMIN", "No se puede desactivar el último administrador activo");
        db.sql("update users set status=:s,updated_at=now() where id=:id and tenant_id=:t").param("s", request.status()).param("id", id).param("t", principal.tenantId()).update();
        audit(principal, "USER_STATUS_CHANGED", id);
        return one(principal, id);
    }

    @PutMapping("/{id}/roles")
    @Transactional
    @PreAuthorize("hasAuthority('IDENTITY_ROLES_ASSIGN')")
    UserDto roles(@AuthenticationPrincipal IdentityPrincipal principal, @PathVariable UUID id,
                  @RequestBody Roles request) {
        owned(principal, id);
        assign(principal, id, request.roleIds());
        audit(principal, "USER_ROLES_UPDATED", id);
        return one(principal, id);
    }

    private void assign(IdentityPrincipal principal, UUID userId, Set<UUID> roleIds) {
        Set<UUID> selected = roleIds == null ? Set.of() : roleIds;
        if (hasRole(userId, "TENANT_ADMIN") && isLastAdmin(principal) && !containsRole(principal, selected, "TENANT_ADMIN"))
            throw new ApiException(HttpStatus.CONFLICT, "LAST_TENANT_ADMIN", "No se puede retirar el rol del último administrador activo");
        for (UUID roleId : selected) {
            int valid = db.sql("select count(*) from roles where id=:r and tenant_id=:t and code<>'PLATFORM_ADMIN' and active")
                    .param("r", roleId).param("t", principal.tenantId()).query(Integer.class).single();
            if (valid == 0) throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_ROLE", "Rol no permitido");
        }
        db.sql("delete from user_roles ur using users u where ur.user_id=u.id and u.id=:u and u.tenant_id=:t")
                .param("u", userId).param("t", principal.tenantId()).update();
        selected.forEach(roleId -> db.sql("insert into user_roles values(:u,:r)").param("u", userId).param("r", roleId).update());
    }

    private boolean containsRole(IdentityPrincipal principal, Set<UUID> ids, String code) {
        if (ids.isEmpty()) return false;
        return db.sql("select count(*) from roles where tenant_id=:t and code=:c and id in (:ids)")
                .param("t", principal.tenantId()).param("c", code).param("ids", ids).query(Integer.class).single() > 0;
    }

    private boolean hasRole(UUID userId, String code) {
        return db.sql("select count(*) from user_roles ur join roles r on r.id=ur.role_id where ur.user_id=:u and r.code=:c")
                .param("u", userId).param("c", code).query(Integer.class).single() > 0;
    }

    private boolean isLastAdmin(IdentityPrincipal principal) {
        return db.sql("select count(*) from users u join user_roles ur on ur.user_id=u.id join roles r on r.id=ur.role_id where u.tenant_id=:t and u.status='ACTIVE' and r.code='TENANT_ADMIN'")
                .param("t", principal.tenantId()).query(Integer.class).single() <= 1;
    }

    private UserDto dto(UUID id, String email, String firstName, String lastName, String phone, String status) {
        List<String> roles = db.sql("select r.code from roles r join user_roles ur on ur.role_id=r.id where ur.user_id=:u order by r.name")
                .param("u", id).query(String.class).list();
        return new UserDto(id, email, firstName, lastName, phone, status, roles);
    }

    private void owned(IdentityPrincipal principal, UUID id) {
        if (db.sql("select count(*) from users where id=:i and tenant_id=:t").param("i", id).param("t", principal.tenantId()).query(Integer.class).single() == 0)
            throw missing();
    }

    private ApiException missing() {
        return new ApiException(HttpStatus.NOT_FOUND, "USER_NOT_FOUND", "Usuario no encontrado");
    }

    private void audit(IdentityPrincipal principal, String action, UUID entity) {
        db.sql("insert into audit_logs(tenant_id,user_id,action,entity_type,entity_id) values(:t,:u,:a,'USER',:e)")
                .param("t", principal.tenantId()).param("u", principal.userId()).param("a", action).param("e", entity).update();
    }
}
