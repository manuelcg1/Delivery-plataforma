package com.delivery.platform.tracking.realtime;

import org.junit.jupiter.api.Test;
import org.springframework.messaging.simp.SimpMessagingTemplate;

import java.util.UUID;

import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;

class RealtimeGatewayTest {
    @Test
    void publishesOnlyToTenantScopedDestination() {
        SimpMessagingTemplate messaging = mock(SimpMessagingTemplate.class);
        RealtimeGateway gateway = new RealtimeGateway(messaging);
        UUID tenant = UUID.randomUUID();
        UUID delivery = UUID.randomUUID();
        gateway.delivery(tenant, delivery, "LocationUpdated", "payload");
        verify(messaging).convertAndSend(eq("/topic/tenants/" + tenant + "/deliveries/" + delivery), any(Object.class));
    }

    @Test
    void publishesCourierNotificationToTheSpecificUserAudience() {
        SimpMessagingTemplate messaging = mock(SimpMessagingTemplate.class);
        RealtimeGateway gateway = new RealtimeGateway(messaging);
        UUID tenant = UUID.randomUUID();
        UUID courierUser = UUID.randomUUID();
        gateway.tenant(tenant, "courier/" + courierUser, "COURIER_ASSIGNMENT_PENDING", "payload");
        verify(messaging).convertAndSend(
                eq("/topic/tenants/" + tenant + "/courier/" + courierUser), any(Object.class));
    }
}
