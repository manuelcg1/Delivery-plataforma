package com.delivery.platform.tracking.realtime;

import com.delivery.platform.tracking.application.TrackingService.Location;

import java.util.UUID;

public interface CourierTrackingEventPublisher {
    void publishLocationUpdated(UUID tenantId, UUID customerUserId, UUID courierId,
                                UUID orderId, UUID deliveryId, String deliveryStatus, Location location);

    void publishDeliveryStatusChanged(UUID tenantId, UUID customerUserId, UUID courierId,
                                      UUID orderId, UUID deliveryId, String deliveryStatus);
}
