package com.delivery.platform.delivery.route;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

@Service
public class OrderRouteService {
    private static final Logger log = LoggerFactory.getLogger(OrderRouteService.class);
    private final JdbcClient db;
    private final RouteProvider provider;
    private final boolean enabled;

    record Candidate(UUID tenantId, UUID orderId, BigDecimal originLat, BigDecimal originLon,
                     BigDecimal destinationLat, BigDecimal destinationLon) {}

    public OrderRouteService(JdbcClient db, List<RouteProvider> providers,
            @Value("${routing.provider:OSRM}") String providerCode,
            @Value("${routing.enabled:true}") boolean enabled) {
        this.db = db;
        this.provider = providers.stream().filter(p -> p.code().equalsIgnoreCase(providerCode)).findFirst()
                .orElseThrow(() -> new IllegalStateException("Route provider not configured: " + providerCode));
        this.enabled = enabled;
    }

    public void generateIfMissing(UUID tenantId, UUID orderId) {
        if (!enabled) return;
        candidate(tenantId, orderId).ifPresent(this::generate);
    }

    @Scheduled(fixedDelayString = "${routing.retry-delay-ms:60000}")
    public void retryMissingRoutes() {
        if (!enabled) return;
        db.sql("""
            select o.tenant_id,o.id,b.latitude,b.longitude,o.delivery_latitude,o.delivery_longitude
            from orders o join branches b on b.id=o.branch_id and b.tenant_id=o.tenant_id
            where o.route_polyline is null and o.status in ('PICKED_UP','ON_THE_WAY')
              and b.latitude is not null and b.longitude is not null
              and o.delivery_latitude is not null and o.delivery_longitude is not null
            order by o.updated_at limit 20
            """).query((r,n)->map(r)).list().forEach(this::generate);
    }

    private java.util.Optional<Candidate> candidate(UUID tenantId, UUID orderId) {
        return db.sql("""
            select o.tenant_id,o.id,b.latitude,b.longitude,o.delivery_latitude,o.delivery_longitude
            from orders o join branches b on b.id=o.branch_id and b.tenant_id=o.tenant_id
            where o.tenant_id=:t and o.id=:o and o.route_polyline is null
              and b.latitude is not null and b.longitude is not null
              and o.delivery_latitude is not null and o.delivery_longitude is not null
            """).param("t",tenantId).param("o",orderId).query((r,n)->map(r)).optional();
    }

    private Candidate map(java.sql.ResultSet r) throws java.sql.SQLException {
        return new Candidate(r.getObject(1,UUID.class),r.getObject(2,UUID.class),r.getBigDecimal(3),
                r.getBigDecimal(4),r.getBigDecimal(5),r.getBigDecimal(6));
    }

    private void generate(Candidate candidate) {
        try {
            RouteProvider.RouteResult route = provider.route(candidate.originLat(),candidate.originLon(),
                    candidate.destinationLat(),candidate.destinationLon());
            int saved = db.sql("""
                update orders set route_polyline=:polyline,route_provider=:provider,route_generated_at=now()
                where tenant_id=:t and id=:o and route_polyline is null
                """).param("polyline",route.polyline()).param("provider",provider.code())
                    .param("t",candidate.tenantId()).param("o",candidate.orderId()).update();
            if (saved == 1) log.info("Visual route generated orderId={} provider={} distanceMeters={} durationSeconds={}",
                    candidate.orderId(),provider.code(),route.distanceMeters(),route.durationSeconds());
        } catch (RuntimeException error) {
            log.warn("Visual route unavailable orderId={} provider={}: {}",candidate.orderId(),provider.code(),error.getMessage());
        }
    }
}
