package com.delivery.platform.delivery.application;

import com.delivery.platform.common.ApiException;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.Optional;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;

@Service
public class DeliveryCoverageService {
    private static final Logger log = LoggerFactory.getLogger(DeliveryCoverageService.class);
    private static final double EARTH_RADIUS_KM = 6371.0088;
    private static final BigDecimal DEFAULT_DELIVERY_FEE = new BigDecimal("5.00");
    private final JdbcClient db;

    public DeliveryCoverageService(JdbcClient db) {
        this.db = db;
    }

    public record Quote(boolean eligible, UUID zoneId, BigDecimal distanceKm,
                        int estimatedMinutes, BigDecimal deliveryFee, String currency,
                        BigDecimal minimumOrderAmount, String reasonCode, String message) {}

    private record Destination(BigDecimal latitude, BigDecimal longitude) {}
    private record BranchCoverage(BigDecimal latitude, BigDecimal longitude,
                                  boolean enabled, BigDecimal radiusKm,
                                  BigDecimal minimumOrder, String currency, int minutes) {}
    private record Rate(UUID zoneId, BigDecimal baseFee, BigDecimal feePerKm,
                        BigDecimal minimumFee, BigDecimal maximumFee,
                        BigDecimal freeDeliveryThreshold) {}

    public Quote quote(UUID tenant, UUID customer, UUID merchant, UUID branch,
                       UUID address, BigDecimal subtotal) {
        try {
            return calculate(tenant, customer, merchant, branch, address, subtotal);
        } catch (ApiException exception) {
            throw exception;
        } catch (DataAccessException exception) {
            log.warn("coverage service database failure merchantId={} branchId={} addressId={}",
                    merchant, branch, address);
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "COVERAGE_SERVICE_ERROR",
                    "No pudimos validar la cobertura. Intenta nuevamente.");
        }
    }

    private Quote calculate(UUID tenant, UUID customer, UUID merchant, UUID branch,
                            UUID address, BigDecimal subtotal) {
        Destination destination = db.sql("select latitude,longitude from delivery_addresses where id=:a and tenant_id=:t and customer_id=:u and active")
                .param("a", address).param("t", tenant).param("u", customer)
                .query((result, row) -> new Destination(result.getBigDecimal("latitude"),
                        result.getBigDecimal("longitude")))
                .optional().orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND,
                        "ADDRESS_NOT_FOUND", "Dirección no encontrada"));
        if (!validCoordinates(destination.latitude(), destination.longitude())) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "ADDRESS_COORDINATES_MISSING",
                    "No pudimos validar esta dirección. Edítala o selecciona otra.");
        }

        BranchCoverage coverage = db.sql("select b.latitude,b.longitude,b.coverage_enabled,b.delivery_radius_km,coalesce(b.minimum_order_amount,0) minimum_order,coalesce(m.default_currency,'PEN') currency,coalesce(b.preparation_time_minutes,30) minutes from branches b join merchants m on m.id=b.merchant_id and m.tenant_id=b.tenant_id where b.id=:b and b.tenant_id=:t and b.merchant_id=:m and b.status='ACTIVE'")
                .param("b", branch).param("t", tenant).param("m", merchant)
                .query((result, row) -> new BranchCoverage(result.getBigDecimal("latitude"),
                        result.getBigDecimal("longitude"), result.getBoolean("coverage_enabled"),
                        result.getBigDecimal("delivery_radius_km"), result.getBigDecimal("minimum_order"),
                        result.getString("currency"), result.getInt("minutes")))
                .optional().orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND,
                        "BRANCH_NOT_FOUND", "Sucursal no encontrada"));

        String configurationError = configurationError(coverage.latitude(), coverage.longitude(),
                coverage.enabled(), coverage.radiusKm());
        if ("BRANCH_LOCATION_MISSING".equals(configurationError)) {
            rejectedLog(merchant, branch, address, coverage, destination, null, false, null);
            return rejected("BRANCH_LOCATION_MISSING",
                    "Esta sucursal todavía no tiene una ubicación configurada.");
        }
        if ("COVERAGE_NOT_CONFIGURED".equals(configurationError)) {
            rejectedLog(merchant, branch, address, coverage, destination, null, false, null);
            return rejected("COVERAGE_NOT_CONFIGURED",
                    "Esta sucursal todavía no tiene una zona de reparto configurada.");
        }

        BigDecimal distance = distanceKm(coverage.latitude(), coverage.longitude(),
                destination.latitude(), destination.longitude());
        boolean covered = distance.compareTo(coverage.radiusKm()) <= 0;
        if (!covered) {
            rejectedLog(merchant, branch, address, coverage, destination, distance, false, null);
            return new Quote(false, null, distance, coverage.minutes(), null, coverage.currency(),
                    coverage.minimumOrder(), "OUTSIDE_COVERAGE",
                    "Este comercio todavía no realiza entregas en esta ubicación.");
        }

        Optional<Rate> configuredRate = db.sql("select z.id,coalesce(r.base_fee,z.base_delivery_fee) base_fee,coalesce(r.fee_per_km,0) fee_per_km,r.minimum_fee,r.maximum_fee,r.free_delivery_threshold from delivery_zones z left join lateral(select * from delivery_rates where delivery_zone_id=z.id and active order by created_at desc limit 1) r on true where z.tenant_id=:t and z.merchant_id=:m and (z.branch_id is null or z.branch_id=:b) and z.active order by (z.branch_id is not null) desc limit 1")
                .param("t", tenant).param("m", merchant).param("b", branch)
                .query((result, row) -> new Rate(result.getObject("id", UUID.class),
                        result.getBigDecimal("base_fee"), result.getBigDecimal("fee_per_km"),
                        result.getBigDecimal("minimum_fee"), result.getBigDecimal("maximum_fee"),
                        result.getBigDecimal("free_delivery_threshold"))).optional();
        Rate rate = configuredRate.orElse(new Rate(null, DEFAULT_DELIVERY_FEE,
                BigDecimal.ZERO, null, null, null));
        BigDecimal fee = rate.baseFee().add(distance.multiply(rate.feePerKm()));
        if (rate.minimumFee() != null) fee = fee.max(rate.minimumFee());
        if (rate.maximumFee() != null) fee = fee.min(rate.maximumFee());
        if (rate.freeDeliveryThreshold() != null
                && subtotal.compareTo(rate.freeDeliveryThreshold()) >= 0) fee = BigDecimal.ZERO;

        rejectedLog(merchant, branch, address, coverage, destination, distance, true, rate.zoneId());
        if (subtotal.compareTo(coverage.minimumOrder()) < 0) {
            return new Quote(false, rate.zoneId(), distance, coverage.minutes(), null,
                    coverage.currency(), coverage.minimumOrder(), "DELIVERY_MINIMUM_NOT_REACHED",
                    "No alcanza el pedido mínimo");
        }
        return new Quote(true, rate.zoneId(), distance, coverage.minutes(),
                fee.setScale(2, RoundingMode.HALF_UP), coverage.currency(),
                coverage.minimumOrder(), null, "Cobertura disponible");
    }

    private Quote rejected(String code, String message) {
        return new Quote(false, null, null, 0, null, null, null, code, message);
    }

    static BigDecimal distanceKm(BigDecimal fromLatitude, BigDecimal fromLongitude,
                                 BigDecimal toLatitude, BigDecimal toLongitude) {
        double lat1 = Math.toRadians(fromLatitude.doubleValue());
        double lat2 = Math.toRadians(toLatitude.doubleValue());
        double deltaLat = lat2 - lat1;
        double deltaLongitude = Math.toRadians(toLongitude.doubleValue() - fromLongitude.doubleValue());
        double haversine = Math.pow(Math.sin(deltaLat / 2), 2)
                + Math.cos(lat1) * Math.cos(lat2) * Math.pow(Math.sin(deltaLongitude / 2), 2);
        double distance = EARTH_RADIUS_KM * 2 * Math.atan2(Math.sqrt(haversine), Math.sqrt(1 - haversine));
        return BigDecimal.valueOf(distance).setScale(2, RoundingMode.HALF_UP);
    }

    static boolean validCoordinates(BigDecimal latitude, BigDecimal longitude) {
        return latitude != null && longitude != null
                && latitude.compareTo(BigDecimal.valueOf(-90)) >= 0
                && latitude.compareTo(BigDecimal.valueOf(90)) <= 0
                && longitude.compareTo(BigDecimal.valueOf(-180)) >= 0
                && longitude.compareTo(BigDecimal.valueOf(180)) <= 0;
    }

    static String configurationError(BigDecimal latitude, BigDecimal longitude,
                                     boolean enabled, BigDecimal radiusKm) {
        if (!validCoordinates(latitude, longitude)) return "BRANCH_LOCATION_MISSING";
        if (!enabled || radiusKm == null || radiusKm.signum() <= 0) return "COVERAGE_NOT_CONFIGURED";
        return null;
    }

    private void rejectedLog(UUID merchantId, UUID branchId, UUID addressId,
                             BranchCoverage coverage, Destination destination,
                             BigDecimal distance, boolean covered, UUID zoneId) {
        log.debug("coverage merchantId={} branchId={} addressId={} branchLat={} branchLng={} customerLat={} customerLng={} distanceKm={} allowedRadiusKm={} coverageEnabled={} covered={} zoneId={}",
                merchantId, branchId, addressId, coverage.latitude(), coverage.longitude(),
                destination.latitude(), destination.longitude(), distance, coverage.radiusKm(),
                coverage.enabled(), covered, zoneId);
    }
}
