package com.delivery.platform.tracking.application;

import com.delivery.platform.common.ApiException;
import com.delivery.platform.delivery.application.DeliveryEtaService;
import com.delivery.platform.identity.security.IdentityPrincipal;
import com.delivery.platform.tracking.realtime.RealtimeGateway;
import com.delivery.platform.tracking.realtime.CourierTrackingEventPublisher;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Duration;
import java.time.Instant;
import java.sql.Timestamp;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

@Service
public class TrackingService {
    public record CourierMe(UUID id, UUID userId, String name, String vehicleType, String phone,
                            String status, int activeDeliveries, int maxActiveDeliveries) {}
    public record Location(UUID id, UUID courierId, UUID deliveryId, BigDecimal latitude,
                           BigDecimal longitude, BigDecimal speed, BigDecimal heading,
                           BigDecimal accuracy, BigDecimal altitude, String provider,
                           Integer batteryLevel, Instant gpsTimestamp, Instant receivedAt) {}
    public record LocationCommand(BigDecimal latitude, BigDecimal longitude, BigDecimal speed,
                                  BigDecimal heading, BigDecimal accuracy, BigDecimal altitude,
                                  String provider, Integer batteryLevel, Instant gpsTimestamp) {}
    public record Eta(BigDecimal distanceRemainingKm, int estimatedMinutes, Instant calculatedAt) {}
    public record Tracking(UUID deliveryId, String status, String deliveryType, UUID courierId,
                           String courierName, String vehicleType, Location location, Eta eta,
                           String addressLine, String district, Instant updatedAt) {}
    record ActiveDelivery(UUID deliveryId, UUID orderId, UUID customerUserId, String status) {}

    private final JdbcClient db;
    private final StringRedisTemplate redis;
    private final RealtimeGateway realtime;
    private final CourierTrackingEventPublisher trackingEvents;
    private final DeliveryEtaService etaService;
    private final CourierArrivalDetectionService arrivals;
    private final BigDecimal maximumAccuracy;
    private final BigDecimal maximumSpeedKph;

    public TrackingService(JdbcClient db, StringRedisTemplate redis, RealtimeGateway realtime,
                           CourierTrackingEventPublisher trackingEvents,
                           DeliveryEtaService etaService,
                           CourierArrivalDetectionService arrivals,
                           @Value("${tracking.maximum-accuracy-meters:100}") BigDecimal maximumAccuracy,
                           @Value("${tracking.maximum-speed-kph:180}") BigDecimal maximumSpeedKph) {
        this.db = db;
        this.redis = redis;
        this.realtime = realtime;
        this.trackingEvents = trackingEvents;
        this.etaService = etaService;
        this.arrivals = arrivals;
        this.maximumAccuracy = maximumAccuracy;
        this.maximumSpeedKph = maximumSpeedKph;
    }

    public CourierMe me(IdentityPrincipal principal) {
        return db.sql("select c.id,c.user_id,u.first_name||' '||u.last_name name,c.vehicle_type,c.phone,c.current_active_deliveries,c.max_active_deliveries,coalesce(a.status,'OFFLINE') availability from courier_profiles c join users u on u.id=c.user_id left join courier_availability a on a.courier_id=c.id where c.tenant_id=:t and c.user_id=:u")
                .param("t", principal.tenantId()).param("u", principal.userId())
                .query((r, n) -> new CourierMe(r.getObject("id", UUID.class), r.getObject("user_id", UUID.class),
                        r.getString("name"), r.getString("vehicle_type"), r.getString("phone"),
                        r.getString("availability"), r.getInt("current_active_deliveries"), r.getInt("max_active_deliveries")))
                .optional().orElseThrow(() -> error(HttpStatus.NOT_FOUND, "COURIER_PROFILE_NOT_FOUND", "El usuario no tiene perfil de repartidor"));
    }

    @Transactional
    public CourierMe status(IdentityPrincipal principal, String status) {
        CourierMe courier = me(principal);
        if (!List.of("OFFLINE", "ONLINE", "BUSY", "PAUSED", "DELIVERING", "SUSPENDED").contains(status))
            throw error(HttpStatus.BAD_REQUEST, "COURIER_STATUS_INVALID", "Estado de repartidor no válido");
        if (status.equals("SUSPENDED") && !principal.permissions().contains("COURIER_MANAGE"))
            throw error(HttpStatus.FORBIDDEN, "COURIER_STATUS_FORBIDDEN", "No puedes suspender este repartidor");
        db.sql("update courier_availability set status=:s,updated_at=now() where tenant_id=:t and courier_id=:c")
                .param("s", status).param("t", principal.tenantId()).param("c", courier.id()).update();
        event(principal.tenantId(), courier.id(), null, "Courier" + title(status), Map.of("status", status));
        return me(principal);
    }

    @Transactional
    public Optional<Location> location(IdentityPrincipal principal, UUID requestedDeliveryId, LocationCommand command) {
        CourierMe courier = me(principal);
        validate(command);
        ActiveDelivery delivery = activeTrackingDelivery(principal.tenantId(), courier.id(), requestedDeliveryId)
                .orElseThrow(() -> error(HttpStatus.CONFLICT, "ACTIVE_DELIVERY_NOT_TRACKABLE",
                        "No existe una entrega activa compatible con el seguimiento"));
        UUID deliveryId = delivery.deliveryId();
        Location previous = current(principal.tenantId(), courier.id()).orElse(null);
        if (previous != null && duplicate(previous, command)) return Optional.empty();
        if (previous != null && impossible(previous, command))
            throw error(HttpStatus.UNPROCESSABLE_ENTITY, "LOCATION_JUMP_IMPOSSIBLE", "La ubicación implica un salto imposible");

        UUID id = UUID.randomUUID();
        db.sql("insert into courier_location_history(id,tenant_id,courier_id,delivery_id,latitude,longitude,speed,heading,accuracy,altitude,provider,battery_level,gps_timestamp) values(:i,:t,:c,:d,:la,:lo,:s,:h,:a,:al,:p,:b,:g)")
                .param("i", id).param("t", principal.tenantId()).param("c", courier.id()).param("d", deliveryId)
                .param("la", command.latitude()).param("lo", command.longitude()).param("s", command.speed())
                .param("h", command.heading()).param("a", command.accuracy()).param("al", command.altitude())
                .param("p", command.provider()).param("b", command.batteryLevel())
                .param("g", Timestamp.from(command.gpsTimestamp())).update();
        db.sql("insert into courier_locations(id,tenant_id,courier_id,latitude,longitude,speed,heading,accuracy,altitude,provider,battery_level,gps_timestamp) values(:i,:t,:c,:la,:lo,:s,:h,:a,:al,:p,:b,:g) on conflict(tenant_id,courier_id) do update set id=excluded.id,latitude=excluded.latitude,longitude=excluded.longitude,speed=excluded.speed,heading=excluded.heading,accuracy=excluded.accuracy,altitude=excluded.altitude,provider=excluded.provider,battery_level=excluded.battery_level,gps_timestamp=excluded.gps_timestamp,received_at=now()")
                .param("i", id).param("t", principal.tenantId()).param("c", courier.id())
                .param("la", command.latitude()).param("lo", command.longitude()).param("s", command.speed())
                .param("h", command.heading()).param("a", command.accuracy()).param("al", command.altitude())
                .param("p", command.provider()).param("b", command.batteryLevel())
                .param("g", Timestamp.from(command.gpsTimestamp())).update();
        Location saved = current(principal.tenantId(), courier.id()).orElseThrow();
        redis.opsForValue().set("tracking:" + principal.tenantId() + ":courier:" + courier.id(),
                command.latitude() + "," + command.longitude() + "," + command.gpsTimestamp(), Duration.ofMinutes(5));
        db.sql("insert into tracking_events(tenant_id,delivery_id,courier_id,event_type,payload) values(:t,:d,:c,'LocationUpdated',cast(:p as jsonb))")
                .param("t", principal.tenantId()).param("d", deliveryId).param("c", courier.id())
                .param("p", "{\"source\":\"courier-api\"}").update();
        trackingEvents.publishLocationUpdated(principal.tenantId(), delivery.customerUserId(), courier.id(),
                delivery.orderId(), deliveryId, delivery.status(), saved);
        arrivals.detect(principal.tenantId(), deliveryId, courier.id(), id, command.latitude(),
                command.longitude(), command.accuracy(), command.gpsTimestamp());
        return Optional.of(saved);
    }

    public Tracking tracking(IdentityPrincipal principal, UUID orderId) {
        Object[] delivery = db.sql("select d.id,d.status,d.delivery_type,d.courier_id,d.address_snapshot->>'addressLine' address_line,d.address_snapshot->>'district' district,c.user_id,u.first_name||' '||u.last_name courier_name,c.vehicle_type,d.updated_at from deliveries d left join courier_profiles c on c.id=d.courier_id left join users u on u.id=c.user_id where d.tenant_id=:t and d.order_id=:o and (d.customer_id=:u or :admin) order by d.created_at desc limit 1")
                .param("t", principal.tenantId()).param("o", orderId).param("u", principal.userId())
                .param("admin", principal.permissions().contains("TRACKING_ADMIN") || principal.permissions().contains("DELIVERY_ADMIN"))
                .query((r, n) -> new Object[]{r.getObject("id", UUID.class), r.getString("status"), r.getString("delivery_type"),
                        r.getObject("courier_id", UUID.class), r.getString("address_line"), r.getString("district"),
                        r.getString("courier_name"), r.getString("vehicle_type"), r.getTimestamp("updated_at").toInstant()})
                .optional().orElseThrow(() -> error(HttpStatus.NOT_FOUND, "TRACKING_NOT_FOUND", "No existe seguimiento para el pedido"));
        Location location = delivery[3] == null ? null : current(principal.tenantId(), (UUID) delivery[3]).orElse(null);
        Eta eta = location == null ? null : eta(location, (UUID) delivery[0]);
        return new Tracking((UUID) delivery[0], (String) delivery[1], (String) delivery[2], (UUID) delivery[3],
                (String) delivery[6], (String) delivery[7], location, eta, (String) delivery[4], (String) delivery[5], (Instant) delivery[8]);
    }

    public List<Location> couriers(IdentityPrincipal principal) {
        return db.sql("select l.*,null::uuid delivery_id from courier_locations l where l.tenant_id=:t order by l.received_at desc")
                .param("t", principal.tenantId()).query((r, n) -> map(r)).list();
    }

    public List<Location> history(IdentityPrincipal principal, UUID courierId, Instant from, Instant to) {
        return db.sql("select h.* from courier_location_history h where h.tenant_id=:t and h.courier_id=:c and (cast(:f as timestamptz) is null or h.gps_timestamp>=:f) and (cast(:x as timestamptz) is null or h.gps_timestamp<=:x) order by h.gps_timestamp desc limit 1000")
                .param("t", principal.tenantId()).param("c", courierId)
                .param("f", from == null ? null : Timestamp.from(from))
                .param("x", to == null ? null : Timestamp.from(to))
                .query((r, n) -> map(r)).list();
    }

    private void validate(LocationCommand command) {
        if (command.latitude() == null || command.longitude() == null || command.accuracy() == null || command.gpsTimestamp() == null)
            throw error(HttpStatus.BAD_REQUEST, "LOCATION_REQUIRED_FIELDS", "Latitud, longitud, precisión y fecha GPS son obligatorias");
        if (command.latitude().abs().compareTo(BigDecimal.valueOf(90)) > 0 || command.longitude().abs().compareTo(BigDecimal.valueOf(180)) > 0)
            throw error(HttpStatus.BAD_REQUEST, "LOCATION_COORDINATES_INVALID", "Coordenadas fuera de rango");
        if (command.accuracy().signum() < 0 || command.accuracy().compareTo(maximumAccuracy) > 0)
            throw error(HttpStatus.UNPROCESSABLE_ENTITY, "LOCATION_ACCURACY_LOW", "La precisión GPS no es suficiente");
        if (command.gpsTimestamp().isAfter(Instant.now().plusSeconds(30)) || command.gpsTimestamp().isBefore(Instant.now().minusSeconds(120)))
            throw error(HttpStatus.UNPROCESSABLE_ENTITY, "LOCATION_TIMESTAMP_INVALID", "La fecha GPS está fuera de la ventana permitida");
    }

    private boolean duplicate(Location previous, LocationCommand current) {
        // Equal coordinates with a newer GPS timestamp are a valid stationary
        // heartbeat used to prove dwell at the customer geofence.
        return previous.gpsTimestamp().equals(current.gpsTimestamp());
    }

    boolean impossible(Location previous, LocationCommand current) {
        long seconds = Math.max(1, Duration.between(previous.gpsTimestamp(), current.gpsTimestamp()).abs().toSeconds());
        double speed = haversine(previous.latitude(), previous.longitude(), current.latitude(), current.longitude()) / seconds * 3600;
        return speed > maximumSpeedKph.doubleValue();
    }

    static double haversine(BigDecimal lat1, BigDecimal lon1, BigDecimal lat2, BigDecimal lon2) {
        double p1 = Math.toRadians(lat1.doubleValue()), p2 = Math.toRadians(lat2.doubleValue());
        double dp = Math.toRadians(lat2.subtract(lat1).doubleValue()), dl = Math.toRadians(lon2.subtract(lon1).doubleValue());
        double a = Math.sin(dp / 2) * Math.sin(dp / 2) + Math.cos(p1) * Math.cos(p2) * Math.sin(dl / 2) * Math.sin(dl / 2);
        return 6371 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    }

    private Eta eta(Location location, UUID deliveryId) {
        Object[] destination = db.sql("select a.latitude,a.longitude from deliveries d join delivery_addresses a on a.id=d.delivery_address_id and a.tenant_id=d.tenant_id where d.id=:d")
                .param("d", deliveryId).query((r, n) -> new Object[]{r.getBigDecimal("latitude"), r.getBigDecimal("longitude")}).optional().orElse(null);
        if (destination == null || destination[0] == null || destination[1] == null)
            return new Eta(null, 0, Instant.now());
        BigDecimal distance = BigDecimal.valueOf(haversine(location.latitude(), location.longitude(), (BigDecimal) destination[0], (BigDecimal) destination[1])).setScale(2, RoundingMode.HALF_UP);
        return new Eta(distance, etaService.remainingMinutes(distance), Instant.now());
    }

    private Optional<Location> current(UUID tenantId, UUID courierId) {
        return db.sql("select l.*,null::uuid delivery_id from courier_locations l where tenant_id=:t and courier_id=:c")
                .param("t", tenantId).param("c", courierId).query((r, n) -> map(r)).optional();
    }

    private Optional<ActiveDelivery> activeTrackingDelivery(UUID tenantId, UUID courierId, UUID deliveryId) {
        List<ActiveDelivery> matches = db.sql("select id,order_id,customer_id,status from deliveries where tenant_id=:t and courier_id=:c and (cast(:d as uuid) is null or id=:d) and status in('PICKED_UP','IN_TRANSIT','ARRIVED_AT_CUSTOMER') order by created_at desc limit 2")
                .param("t", tenantId).param("c", courierId).param("d", deliveryId)
                .query((r, n) -> new ActiveDelivery(r.getObject("id", UUID.class),
                        r.getObject("order_id", UUID.class), r.getObject("customer_id", UUID.class),
                        r.getString("status"))).list();
        return matches.size() == 1 ? Optional.of(matches.getFirst()) : Optional.empty();
    }

    private Location map(java.sql.ResultSet r) throws java.sql.SQLException {
        return new Location(r.getObject("id", UUID.class), r.getObject("courier_id", UUID.class),
                r.getObject("delivery_id", UUID.class), r.getBigDecimal("latitude"), r.getBigDecimal("longitude"),
                r.getBigDecimal("speed"), r.getBigDecimal("heading"), r.getBigDecimal("accuracy"),
                r.getBigDecimal("altitude"), r.getString("provider"), (Integer) r.getObject("battery_level"),
                r.getTimestamp("gps_timestamp").toInstant(), r.getTimestamp("received_at").toInstant());
    }

    private void event(UUID tenantId, UUID courierId, UUID deliveryId, String type, Object payload) {
        db.sql("insert into tracking_events(tenant_id,delivery_id,courier_id,event_type,payload) values(:t,:d,:c,:e,cast(:p as jsonb))")
                .param("t", tenantId).param("d", deliveryId).param("c", courierId).param("e", type)
                .param("p", "{\"source\":\"courier-api\"}").update();
        realtime.tenant(tenantId, "admin", type, payload);
        realtime.tenant(tenantId, "courier", type, payload);
        if (deliveryId != null) realtime.delivery(tenantId, deliveryId, type, payload);
    }

    private String title(String value) {
        return value.substring(0, 1) + value.substring(1).toLowerCase();
    }

    private ApiException error(HttpStatus status, String code, String message) {
        return new ApiException(status, code, message);
    }
}
