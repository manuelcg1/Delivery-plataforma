package com.delivery.platform.tracking.realtime;

import org.junit.jupiter.api.Test;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.mockito.ArgumentCaptor;
import java.util.Map;

import java.util.UUID;

import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;

class RealtimeGatewayTest {
    @Test void suspendedMerchantDoesNotReceiveEventsOnExistingSubscriptions() {
        var messaging=mock(SimpMessagingTemplate.class);
        var db=mock(org.springframework.jdbc.core.simple.JdbcClient.class,org.mockito.Mockito.RETURNS_DEEP_STUBS);
        UUID tenant=UUID.randomUUID(),merchant=UUID.randomUUID();
        org.mockito.Mockito.when(db.sql(org.mockito.ArgumentMatchers.anyString()).params(merchant,tenant).query(Integer.class).single()).thenReturn(0);
        new RealtimeGateway(messaging,db,mock(CourierTrackingEventPublisher.class))
                .tenant(tenant,"merchant/"+merchant,"ORDER_UPDATED",Map.of("orderId",UUID.randomUUID()));
        org.mockito.Mockito.verifyNoInteractions(messaging);
    }
    @Test
    void publishesOnlyToTenantScopedDestination() {
        SimpMessagingTemplate messaging = mock(SimpMessagingTemplate.class);
        RealtimeGateway gateway = new RealtimeGateway(messaging,
                mock(org.springframework.jdbc.core.simple.JdbcClient.class, org.mockito.Mockito.RETURNS_DEEP_STUBS),
                mock(CourierTrackingEventPublisher.class));
        UUID tenant = UUID.randomUUID();
        UUID delivery = UUID.randomUUID();
        gateway.delivery(tenant, delivery, "LocationUpdated", "payload");
        verify(messaging).convertAndSend(eq("/topic/tenants/" + tenant + "/deliveries/" + delivery), any(Object.class));
    }

    @Test
    void publishesCourierNotificationToTheSpecificUserAudience() {
        SimpMessagingTemplate messaging = mock(SimpMessagingTemplate.class);
        RealtimeGateway gateway = new RealtimeGateway(messaging,
                mock(org.springframework.jdbc.core.simple.JdbcClient.class, org.mockito.Mockito.RETURNS_DEEP_STUBS),
                mock(CourierTrackingEventPublisher.class));
        UUID tenant = UUID.randomUUID();
        UUID courierUser = UUID.randomUUID();
        gateway.tenant(tenant, "courier/" + courierUser, "COURIER_ASSIGNMENT_PENDING", "payload");
        verify(messaging).convertAndSend(
                eq("/topic/tenants/" + tenant + "/courier/" + courierUser), any(Object.class));
    }

    @Test
    void customerRefreshDoesNotPublishOrderIdentifiersOrCustomerData() {
        SimpMessagingTemplate messaging = mock(SimpMessagingTemplate.class);
        RealtimeGateway gateway = new RealtimeGateway(messaging,
                mock(org.springframework.jdbc.core.simple.JdbcClient.class, org.mockito.Mockito.RETURNS_DEEP_STUBS),
                mock(CourierTrackingEventPublisher.class));
        UUID tenant = UUID.randomUUID();

        gateway.customerRefresh(tenant);

        ArgumentCaptor<Object> payload = ArgumentCaptor.forClass(Object.class);
        verify(messaging).convertAndSend(eq("/topic/tenants/" + tenant + "/customers"), payload.capture());
        Map<?, ?> envelope = (Map<?, ?>) payload.getValue();
        Map<?, ?> event = (Map<?, ?>) envelope.get("payload");
        org.junit.jupiter.api.Assertions.assertEquals(java.util.Set.of("status"), event.keySet());
        org.junit.jupiter.api.Assertions.assertFalse(event.containsKey("orderId"));
        org.junit.jupiter.api.Assertions.assertFalse(event.containsKey("customerName"));
        org.junit.jupiter.api.Assertions.assertFalse(event.containsKey("customerId"));
    }
}
