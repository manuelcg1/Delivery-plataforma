package com.delivery.platform.tracking.customer;

import java.time.Instant;
import java.util.UUID;

public record CustomerOrderTrackingResponse(
        UUID orderId,
        UUID deliveryId,
        String deliveryStatus,
        CourierTrackingSummary courier,
        TrackingLocationResponse location,
        Instant updatedAt,
        boolean trackingActive,
        boolean stale
) {}
