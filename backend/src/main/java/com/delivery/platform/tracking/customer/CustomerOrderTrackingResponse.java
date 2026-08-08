package com.delivery.platform.tracking.customer;

import java.time.Instant;
import java.util.UUID;

public record CustomerOrderTrackingResponse(
        UUID orderId,
        UUID deliveryId,
        String deliveryStatus,
        CourierTrackingSummary courier,
        TrackingLocationResponse location,
        TrackingRouteResponse route,
        Instant updatedAt,
        boolean trackingActive,
        boolean stale
) {
    public CustomerOrderTrackingResponse(UUID orderId, UUID deliveryId, String deliveryStatus,
            CourierTrackingSummary courier, TrackingLocationResponse location, Instant updatedAt,
            boolean trackingActive, boolean stale) {
        this(orderId, deliveryId, deliveryStatus, courier, location, null, updatedAt, trackingActive, stale);
    }
}
