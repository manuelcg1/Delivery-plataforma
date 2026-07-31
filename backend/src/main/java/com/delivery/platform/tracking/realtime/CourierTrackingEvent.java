package com.delivery.platform.tracking.realtime;

import com.delivery.platform.tracking.customer.TrackingLocationResponse;

import java.time.Instant;
import java.util.UUID;

public record CourierTrackingEvent(
        String type,
        UUID orderId,
        UUID deliveryId,
        String deliveryStatus,
        TrackingLocationResponse location,
        Instant publishedAt
) {}
