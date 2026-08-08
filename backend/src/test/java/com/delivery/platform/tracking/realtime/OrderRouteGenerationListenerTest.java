package com.delivery.platform.tracking.realtime;

import com.delivery.platform.delivery.route.OrderRouteService;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.UUID;

import static org.mockito.Mockito.*;

class OrderRouteGenerationListenerTest {
    @Test void generatesOnlyForTrackingStartedEvent() {
        OrderRouteService routes = mock(OrderRouteService.class);
        OrderRouteGenerationListener listener = new OrderRouteGenerationListener(routes);
        UUID tenant = UUID.randomUUID();
        UUID order = UUID.randomUUID();
        UUID delivery = UUID.randomUUID();
        UUID customer = UUID.randomUUID();
        UUID courier = UUID.randomUUID();

        listener.afterPickup(event(tenant, customer, courier,
                new CourierTrackingEvent("TRACKING_STARTED", order, delivery, "PICKED_UP", null, Instant.now())));
        listener.afterPickup(event(tenant, customer, courier,
                new CourierTrackingEvent("COURIER_LOCATION_UPDATED", order, delivery, "IN_TRANSIT", null, Instant.now())));

        verify(routes, times(1)).generateIfMissing(tenant, order);
        verifyNoMoreInteractions(routes);
    }

    private PendingCourierTrackingEvent event(UUID tenant, UUID customer, UUID courier,
                                               CourierTrackingEvent event) {
        return new PendingCourierTrackingEvent(tenant, customer, courier, event);
    }
}
