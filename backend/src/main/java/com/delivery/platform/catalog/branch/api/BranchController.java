package com.delivery.platform.catalog.branch.api;

import com.delivery.platform.catalog.common.CatalogSupport;
import com.delivery.platform.common.ApiException;
import com.delivery.platform.identity.security.IdentityPrincipal;
import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class BranchController {
    private final JdbcClient db;
    private final CatalogSupport support;

    public BranchController(JdbcClient db, CatalogSupport support) {
        this.db = db;
        this.support = support;
    }

    public record Branch(UUID id, UUID merchantId, String code, String name,
                         String addressLine, String formattedAddress, String placeId,
                         String district, String city, String province, String region,
                         String countryCode, String phone, String status, String timezone,
                         BigDecimal latitude, BigDecimal longitude, boolean coverageEnabled,
                         BigDecimal deliveryRadiusKm) {}

    public record Save(@NotBlank String code, @NotBlank String name,
                       @NotBlank String addressLine, @NotBlank String formattedAddress,
                       @NotBlank String placeId, String district, String city,
                       String province, String region,
                       @Pattern(regexp = "[A-Z]{2}") String countryCode,
                       String phone, @NotBlank String timezone,
                       @DecimalMin("-90") @DecimalMax("90") BigDecimal latitude,
                       @DecimalMin("-180") @DecimalMax("180") BigDecimal longitude,
                       boolean coverageEnabled,
                       @DecimalMin(value = "0", inclusive = false) BigDecimal deliveryRadiusKm) {}

    public record Status(@Pattern(regexp = "ACTIVE|INACTIVE|TEMPORARILY_CLOSED") String status) {}

    @GetMapping("/api/v1/merchants/{merchantId}/branches")
    @PreAuthorize("hasAuthority('CATALOG_BRANCHES_VIEW')")
    List<Branch> list(@AuthenticationPrincipal IdentityPrincipal principal,
                      @PathVariable UUID merchantId) {
        support.merchant(principal, merchantId);
        return db.sql("select * from branches where tenant_id=:t and merchant_id=:m order by name")
                .param("t", principal.tenantId()).param("m", merchantId)
                .query((result, row) -> map(result)).list();
    }

    @PostMapping("/api/v1/merchants/{merchantId}/branches")
    @Transactional
    @PreAuthorize("hasAuthority('CATALOG_BRANCHES_CREATE')")
    Branch create(@AuthenticationPrincipal IdentityPrincipal principal,
                  @PathVariable UUID merchantId, @Valid @RequestBody Save request) {
        support.merchant(principal, merchantId);
        validateLocation(request);
        UUID id = UUID.randomUUID();
        db.sql("insert into branches(id,tenant_id,merchant_id,code,name,address_line,formatted_address,place_id,district,city,province,department,region,country_code,phone,timezone,latitude,longitude,coverage_enabled,delivery_radius_km) values(:i,:t,:m,lower(:c),:n,:a,:fa,:pi,:d,:ci,:p,:r,:r,:co,:ph,:tz,:la,:lo,:ce,:ra)")
                .param("i", id).param("t", principal.tenantId()).param("m", merchantId)
                .param("c", request.code()).param("n", request.name()).param("a", request.addressLine())
                .param("fa", request.formattedAddress()).param("pi", request.placeId())
                .param("d", request.district()).param("ci", request.city()).param("p", request.province())
                .param("r", request.region()).param("co", country(request.countryCode()))
                .param("ph", request.phone()).param("tz", request.timezone())
                .param("la", request.latitude()).param("lo", request.longitude())
                .param("ce", request.coverageEnabled()).param("ra", request.deliveryRadiusKm()).update();
        support.audit(principal, "BRANCH_CREATED", "BRANCH", id);
        return one(principal, id);
    }

    @GetMapping("/api/v1/branches/{id}")
    @PreAuthorize("hasAuthority('CATALOG_BRANCHES_VIEW')")
    Branch one(@AuthenticationPrincipal IdentityPrincipal principal, @PathVariable UUID id) {
        support.branch(principal, id);
        return db.sql("select * from branches where id=:i and tenant_id=:t")
                .param("i", id).param("t", principal.tenantId())
                .query((result, row) -> map(result)).single();
    }

    @PutMapping("/api/v1/branches/{id}")
    @Transactional
    @PreAuthorize("hasAuthority('CATALOG_BRANCHES_UPDATE')")
    Branch update(@AuthenticationPrincipal IdentityPrincipal principal, @PathVariable UUID id,
                  @Valid @RequestBody Save request) {
        support.branch(principal, id);
        validateLocation(request);
        db.sql("update branches set code=lower(:c),name=:n,address_line=:a,formatted_address=:fa,place_id=:pi,district=:d,city=:ci,province=:p,department=:r,region=:r,country_code=:co,phone=:ph,timezone=:tz,latitude=:la,longitude=:lo,coverage_enabled=:ce,delivery_radius_km=:ra,updated_at=now() where id=:i and tenant_id=:t")
                .param("c", request.code()).param("n", request.name()).param("a", request.addressLine())
                .param("fa", request.formattedAddress()).param("pi", request.placeId())
                .param("d", request.district()).param("ci", request.city()).param("p", request.province())
                .param("r", request.region()).param("co", country(request.countryCode()))
                .param("ph", request.phone()).param("tz", request.timezone())
                .param("la", request.latitude()).param("lo", request.longitude())
                .param("ce", request.coverageEnabled()).param("ra", request.deliveryRadiusKm())
                .param("i", id).param("t", principal.tenantId()).update();
        support.audit(principal, "BRANCH_UPDATED", "BRANCH", id);
        return one(principal, id);
    }

    @PatchMapping("/api/v1/branches/{id}/status")
    @Transactional
    @PreAuthorize("hasAuthority('CATALOG_BRANCHES_DISABLE')")
    Branch status(@AuthenticationPrincipal IdentityPrincipal principal, @PathVariable UUID id,
                  @Valid @RequestBody Status request) {
        support.branch(principal, id);
        db.sql("update branches set status=:s,updated_at=now() where id=:i and tenant_id=:t")
                .param("s", request.status()).param("i", id).param("t", principal.tenantId()).update();
        support.audit(principal, "BRANCH_STATUS_CHANGED", "BRANCH", id);
        return one(principal, id);
    }

    private void validateLocation(Save request) {
        if (request.latitude() == null || request.longitude() == null) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "BRANCH_LOCATION_MISSING",
                    "Selecciona una dirección válida para la sucursal.");
        }
        if (request.coverageEnabled() && request.deliveryRadiusKm() == null) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "COVERAGE_NOT_CONFIGURED",
                    "Configura un radio de reparto mayor que cero.");
        }
    }

    private String country(String value) {
        return value == null ? "PE" : value;
    }

    private Branch map(java.sql.ResultSet result) throws java.sql.SQLException {
        return new Branch(result.getObject("id", UUID.class), result.getObject("merchant_id", UUID.class),
                result.getString("code"), result.getString("name"), result.getString("address_line"),
                result.getString("formatted_address"), result.getString("place_id"), result.getString("district"),
                result.getString("city"), result.getString("province"), result.getString("region"),
                result.getString("country_code"), result.getString("phone"), result.getString("status"),
                result.getString("timezone"), result.getBigDecimal("latitude"), result.getBigDecimal("longitude"),
                result.getBoolean("coverage_enabled"), result.getBigDecimal("delivery_radius_km"));
    }
}
