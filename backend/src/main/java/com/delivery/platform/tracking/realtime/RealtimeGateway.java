package com.delivery.platform.tracking.realtime;

import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Component;

import java.util.Map;
import java.util.UUID;

@Component
public class RealtimeGateway {
    private final SimpMessagingTemplate messaging;

    public RealtimeGateway(SimpMessagingTemplate messaging) {
        this.messaging = messaging;
    }

    public void tenant(UUID tenantId, String audience, String event, Object payload) {
        messaging.convertAndSend("/topic/tenants/" + tenantId + "/" + audience,
                Map.of("event", event, "payload", payload));
    }

    public void delivery(UUID tenantId, UUID deliveryId, String event, Object payload) {
        messaging.convertAndSend("/topic/tenants/" + tenantId + "/deliveries/" + deliveryId,
                Map.of("event", event, "payload", payload));
    }
}
