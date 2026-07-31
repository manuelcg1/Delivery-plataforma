package com.delivery.platform.tracking.customer;

import java.time.Instant;

public record TrackingLocationResponse(
        double latitude,
        double longitude,
        Double speed,
        Double heading,
        double accuracy,
        Double altitude,
        Instant gpsTimestamp
) {}
