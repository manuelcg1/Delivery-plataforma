package com.delivery.platform.catalog.common;

import com.delivery.platform.catalog.cache.CatalogCache;
import com.delivery.platform.common.ApiException;
import com.delivery.platform.identity.security.IdentityPrincipal;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;

import java.util.Set;
import java.util.UUID;

@Component
public class CatalogSupport {
	private static final Set<String> TENANT_WIDE_ROLES = Set.of("TENANT_ADMIN", "PLATFORM_ADMIN", "ROLE_PLATFORM_OWNER");
	private final JdbcClient db;
	private final CatalogCache cache;

	public CatalogSupport(JdbcClient db, CatalogCache cache) {
		this.db = db;
		this.cache = cache;
	}

	public void merchant(IdentityPrincipal principal, UUID id) {
		requireOwnedResource("merchants", principal, id, "MERCHANT_NOT_FOUND", "Comercio no encontrado");
	}

	public void branch(IdentityPrincipal principal, UUID id) {
		requireOwnedResource("branches", principal, id, "BRANCH_NOT_FOUND", "Sucursal no encontrada");
	}

	public void category(IdentityPrincipal principal, UUID id) {
		requireOwnedResource("categories", principal, id, "CATEGORY_NOT_FOUND", "Categoría no encontrada");
	}

	public void product(IdentityPrincipal principal, UUID id) {
		requireOwnedResource("products", principal, id, "PRODUCT_NOT_FOUND", "Producto no encontrado");
	}

	private void requireOwnedResource(String table, IdentityPrincipal principal, UUID id, String code, String message) {
		if (!Set.of("merchants", "branches", "categories", "products").contains(table)) {
			throw new IllegalArgumentException("Unsupported catalog resource");
		}
		boolean tenantAdmin = principal.roles().stream().anyMatch(TENANT_WIDE_ROLES::contains);
		String ownerExpression = table.equals("merchants") ? "resource.id" : "resource.merchant_id";
		String sql = """
				select count(*) from %s resource
				where resource.id=:id and resource.tenant_id=:tenant
				  and (:tenantAdmin or exists (
					select 1 from merchant_memberships membership
					where membership.tenant_id=resource.tenant_id
					  and membership.merchant_id=%s
					  and membership.user_id=:user and membership.active
					  and (not :isBranch or exists (
						select 1 from merchant_branch_assignments assignment
						where assignment.membership_id=membership.id and assignment.branch_id=resource.id
					  ))
				  ))
				""".formatted(table, ownerExpression);
		int count = db.sql(sql)
				.param("id", id)
				.param("tenant", principal.tenantId())
				.param("user", principal.userId())
				.param("tenantAdmin", tenantAdmin)
				.param("isBranch", table.equals("branches"))
				.query(Integer.class)
				.single();
		if (count == 0) throw new ApiException(HttpStatus.NOT_FOUND, code, message);
	}

	public void audit(IdentityPrincipal principal, String action, String type, UUID id) {
		db.sql("insert into audit_logs(tenant_id,user_id,action,entity_type,entity_id) values(:t,:u,:a,:y,:e)")
				.param("t", principal.tenantId()).param("u", principal.userId()).param("a", action)
				.param("y", type).param("e", id).update();
		cache.invalidate(principal.tenantId());
	}

	public ApiException conflict(String code, String message) {
		return new ApiException(HttpStatus.CONFLICT, code, message);
	}
}
