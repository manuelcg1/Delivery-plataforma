package com.delivery.platform.tracking.courier;

import com.delivery.platform.common.ApiException;
import com.delivery.platform.identity.security.IdentityPrincipal;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.UUID;

@Service
public class CourierDeliveryRouteService {
    private final JdbcClient db;

    public CourierDeliveryRouteService(JdbcClient db) {
        this.db = db;
    }

    public RouteView get(UUID deliveryId, IdentityPrincipal principal) {
        return db.sql("""
                select d.id delivery_id,d.order_id,d.status,o.order_number,
                       d.address_snapshot->>'recipientName' customer_name,
                       d.address_snapshot->>'phone' customer_phone,
                       coalesce(o.delivery_address_text,d.address_snapshot->>'addressLine') destination_address,
                       o.delivery_reference,d.delivery_notes,
                       b.name merchant_name,m.name merchant_display_name,b.name branch_name,
                       coalesce(b.formatted_address,b.address_line) merchant_address,
                       b.latitude origin_latitude,b.longitude origin_longitude,
                       o.delivery_latitude destination_latitude,o.delivery_longitude destination_longitude,
                       o.route_polyline,o.route_provider,o.route_generated_at,
                       coalesce(d.distance_km,o.delivery_distance_km) distance_km,
                       coalesce(o.eta_merchant_to_customer_minutes,d.estimated_duration_minutes) eta_minutes
                  from deliveries d
                  join orders o on o.id=d.order_id and o.tenant_id=d.tenant_id
                  join branches b on b.id=d.branch_id and b.tenant_id=d.tenant_id
                  join merchants m on m.id=d.merchant_id and m.tenant_id=d.tenant_id
                  join courier_profiles c on c.id=d.courier_id and c.tenant_id=d.tenant_id
                 where d.id=:delivery and d.tenant_id=:tenant and c.user_id=:user
                """).param("delivery", deliveryId).param("tenant", principal.tenantId())
                .param("user", principal.userId()).query((rs, row) -> new RouteView(
                        rs.getObject("delivery_id", UUID.class), rs.getObject("order_id", UUID.class),
                        rs.getString("status"), rs.getString("order_number"), rs.getString("customer_name"),
                        rs.getString("customer_phone"), rs.getString("destination_address"),
                        rs.getString("delivery_reference"), rs.getString("delivery_notes"),
                        rs.getString("merchant_name"), rs.getString("merchant_display_name"),
                        rs.getString("branch_name"), rs.getString("merchant_address"),
                        number(rs, "origin_latitude"), number(rs, "origin_longitude"),
                        number(rs, "destination_latitude"), number(rs, "destination_longitude"),
                        rs.getString("route_polyline"), rs.getString("route_provider"),
                        instant(rs, "route_generated_at"), number(rs, "distance_km"),
                        (Integer) rs.getObject("eta_minutes"))).optional()
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "COURIER_ROUTE_NOT_FOUND",
                        "No se encontró la ruta de esta entrega"));
    }

    private static Double number(java.sql.ResultSet rs, String column) throws java.sql.SQLException {
        var value = rs.getBigDecimal(column);
        return value == null ? null : value.doubleValue();
    }

    private static Instant instant(java.sql.ResultSet rs, String column) throws java.sql.SQLException {
        var value = rs.getTimestamp(column);
        return value == null ? null : value.toInstant();
    }

    public record RouteView(UUID deliveryId, UUID orderId, String deliveryStatus, String orderNumber,
                            String customerName, String customerPhone, String destinationAddress,
                            String destinationReference, String deliveryNotes, String merchantName,
                            String merchantDisplayName, String branchName, String merchantAddress,
                            Double originLatitude, Double originLongitude,
                            Double destinationLatitude, Double destinationLongitude, String routePolyline,
                            String routeProvider, Instant routeGeneratedAt, Double distanceKm,
                            Integer etaMinutes) {}
}
