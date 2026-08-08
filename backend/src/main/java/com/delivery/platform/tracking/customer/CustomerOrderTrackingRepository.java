package com.delivery.platform.tracking.customer;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

public interface CustomerOrderTrackingRepository {
    Optional<TrackingSnapshot> findOwned(UUID tenantId, UUID customerId, UUID orderId);

    record TrackingSnapshot(UUID orderId, UUID deliveryId, String status, UUID courierId, String courierName,
                            Double latitude, Double longitude, Double speed, Double heading, Double accuracy,
                            Double altitude, Instant gpsTimestamp, Instant receivedAt,
                            String routePolyline, String routeProvider, Instant routeGeneratedAt,
                            Double originLatitude, Double originLongitude,
                            Double destinationLatitude, Double destinationLongitude) {
        TrackingSnapshot(UUID orderId, UUID deliveryId, String status, UUID courierId, String courierName,
                Double latitude, Double longitude, Double speed, Double heading, Double accuracy,
                Double altitude, Instant gpsTimestamp, Instant receivedAt) {
            this(orderId, deliveryId, status, courierId, courierName, latitude, longitude, speed, heading,
                    accuracy, altitude, gpsTimestamp, receivedAt, null, null, null, null, null, null, null);
        }
    }
}
