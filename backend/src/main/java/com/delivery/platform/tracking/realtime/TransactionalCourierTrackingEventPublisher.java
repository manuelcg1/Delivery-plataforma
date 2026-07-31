package com.delivery.platform.tracking.realtime;

import com.delivery.platform.tracking.application.TrackingService.Location;
import com.delivery.platform.tracking.customer.TrackingLocationResponse;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Component;

import java.time.Clock;
import java.util.Set;
import java.util.UUID;

@Component
public class TransactionalCourierTrackingEventPublisher implements CourierTrackingEventPublisher {
    private static final Set<String> TERMINAL = Set.of("DELIVERED", "FAILED", "CANCELLED", "REJECTED", "EXPIRED");
    private final ApplicationEventPublisher events;
    private final Clock clock;

    public TransactionalCourierTrackingEventPublisher(ApplicationEventPublisher events, Clock clock) {
        this.events = events;
        this.clock = clock;
    }

    @Override
    public void publishLocationUpdated(UUID tenantId, UUID customerUserId, UUID courierId,
            UUID orderId, UUID deliveryId, String deliveryStatus, Location location) {
        var payload = new TrackingLocationResponse(location.latitude().doubleValue(),
                location.longitude().doubleValue(), value(location.speed()), value(location.heading()),
                location.accuracy().doubleValue(), value(location.altitude()), location.gpsTimestamp());
        publish(tenantId, customerUserId, courierId, new CourierTrackingEvent(
                "COURIER_LOCATION_UPDATED", orderId, deliveryId, deliveryStatus, payload, clock.instant()));
    }

    @Override
    public void publishDeliveryStatusChanged(UUID tenantId, UUID customerUserId, UUID courierId,
            UUID orderId, UUID deliveryId, String deliveryStatus) {
        String type = "PICKED_UP".equals(deliveryStatus) ? "TRACKING_STARTED"
                : TERMINAL.contains(deliveryStatus) ? "TRACKING_STOPPED" : "DELIVERY_STATUS_CHANGED";
        publish(tenantId, customerUserId, courierId, new CourierTrackingEvent(
                type, orderId, deliveryId, deliveryStatus, null, clock.instant()));
    }

    private void publish(UUID tenantId, UUID customerUserId, UUID courierId, CourierTrackingEvent event) {
        events.publishEvent(new PendingCourierTrackingEvent(tenantId, customerUserId, courierId, event));
    }

    private static Double value(java.math.BigDecimal value) {
        return value == null ? null : value.doubleValue();
    }
}
