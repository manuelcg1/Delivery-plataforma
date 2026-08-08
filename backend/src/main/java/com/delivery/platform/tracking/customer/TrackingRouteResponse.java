package com.delivery.platform.tracking.customer;

import java.time.Instant;

public record TrackingRouteResponse(
        String polyline,
        String provider,
        Instant generatedAt,
        double originLatitude,
        double originLongitude,
        double destinationLatitude,
        double destinationLongitude
) {}
