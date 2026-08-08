package com.delivery.platform.tracking.realtime;

import com.delivery.platform.delivery.route.OrderRouteService;
import org.springframework.stereotype.Component;
import org.springframework.scheduling.annotation.Async;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

@Component
public class OrderRouteGenerationListener {
    private final OrderRouteService routes;

    public OrderRouteGenerationListener(OrderRouteService routes) { this.routes = routes; }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    @Async
    public void afterPickup(PendingCourierTrackingEvent pending) {
        if ("TRACKING_STARTED".equals(pending.event().type())) {
            routes.generateIfMissing(pending.tenantId(), pending.event().orderId());
        }
    }
}
