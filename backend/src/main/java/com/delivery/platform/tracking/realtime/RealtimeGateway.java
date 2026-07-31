package com.delivery.platform.tracking.realtime;

import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;

import java.util.Map;
import java.util.UUID;

@Component
public class RealtimeGateway {
    private final SimpMessagingTemplate messaging;
    private final JdbcClient db;
    private final CourierTrackingEventPublisher trackingEvents;

    public RealtimeGateway(SimpMessagingTemplate messaging, JdbcClient db,
                           CourierTrackingEventPublisher trackingEvents) {
        this.messaging = messaging;
        this.db = db;
        this.trackingEvents = trackingEvents;
    }

    public void tenant(UUID tenantId, String audience, String event, Object payload) {
        messaging.convertAndSend("/topic/tenants/" + tenantId + "/" + audience,
                Map.of("event", event, "payload", payload));
    }

    public void delivery(UUID tenantId, UUID deliveryId, String event, Object payload) {
        messaging.convertAndSend("/topic/tenants/" + tenantId + "/deliveries/" + deliveryId,
                Map.of("event", event, "payload", payload));
        db.sql("select order_id,customer_id,courier_id,status from deliveries where tenant_id=:tenant and id=:delivery")
                .param("tenant", tenantId).param("delivery", deliveryId)
                .query((rs, n) -> new DeliveryAudience(rs.getObject("order_id", UUID.class),
                        rs.getObject("customer_id", UUID.class), rs.getObject("courier_id", UUID.class),
                        rs.getString("status"))).optional()
                .ifPresent(audience -> trackingEvents.publishDeliveryStatusChanged(tenantId,
                        audience.customerId(), audience.courierId(), audience.orderId(), deliveryId,
                        audience.status()));
    }

    record DeliveryAudience(UUID orderId, UUID customerId, UUID courierId, String status) {}
}
