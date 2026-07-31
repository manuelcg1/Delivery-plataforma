package com.delivery.platform.tracking.realtime;

import com.delivery.platform.tracking.application.TrackingService.Location;
import org.junit.jupiter.api.Test;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.messaging.simp.SimpMessagingTemplate;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentCaptor.forClass;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

class CourierTrackingEventPublisherTest {
    @Test void newLocationCreatesACommitAwareDomainEvent() {
        var events = mock(ApplicationEventPublisher.class);
        var now = Instant.parse("2026-07-31T15:30:01Z");
        var publisher = new TransactionalCourierTrackingEventPublisher(events, Clock.fixed(now, ZoneOffset.UTC));
        UUID tenant=UUID.randomUUID(), customer=UUID.randomUUID(), courier=UUID.randomUUID();
        UUID order=UUID.randomUUID(), delivery=UUID.randomUUID();
        publisher.publishLocationUpdated(tenant, customer, courier, order, delivery, "IN_TRANSIT",
                location(courier, delivery));
        var captor = forClass(PendingCourierTrackingEvent.class);
        verify(events).publishEvent(captor.capture());
        assertThat(captor.getValue().event().type()).isEqualTo("COURIER_LOCATION_UPDATED");
        assertThat(captor.getValue().event().publishedAt()).isEqualTo(now);
    }

    @Test void deliveredCreatesTrackingStopped() {
        var events = mock(ApplicationEventPublisher.class);
        var publisher = new TransactionalCourierTrackingEventPublisher(events, Clock.systemUTC());
        publisher.publishDeliveryStatusChanged(UUID.randomUUID(), UUID.randomUUID(), UUID.randomUUID(),
                UUID.randomUUID(), UUID.randomUUID(), "DELIVERED");
        var captor = forClass(PendingCourierTrackingEvent.class);
        verify(events).publishEvent(captor.capture());
        assertThat(captor.getValue().event().type()).isEqualTo("TRACKING_STOPPED");
    }

    @Test void afterCommitListenerTargetsOnlyTheOwningUserQueue() {
        var messaging = mock(SimpMessagingTemplate.class);
        var listener = new StompCourierTrackingEventListener(messaging);
        UUID customer=UUID.randomUUID(), order=UUID.randomUUID();
        var event = new CourierTrackingEvent("TRACKING_STARTED", order, UUID.randomUUID(),
                "PICKED_UP", null, Instant.now());
        listener.publish(new PendingCourierTrackingEvent(UUID.randomUUID(), customer, UUID.randomUUID(), event));
        verify(messaging).convertAndSendToUser(eq(customer.toString()),
                eq("/queue/orders/" + order + "/tracking"), eq(event));
    }

    private Location location(UUID courier, UUID delivery) {
        Instant gps = Instant.parse("2026-07-31T15:30:00Z");
        return new Location(UUID.randomUUID(), courier, delivery, new BigDecimal("-12.0464"),
                new BigDecimal("-77.0428"), new BigDecimal("25"), new BigDecimal("180"),
                new BigDecimal("8"), new BigDecimal("120"), "gps", 80, gps, gps.plusSeconds(1));
    }
}
