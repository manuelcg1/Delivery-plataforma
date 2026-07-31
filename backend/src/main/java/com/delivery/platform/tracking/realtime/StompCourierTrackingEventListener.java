package com.delivery.platform.tracking.realtime;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

@Component
public class StompCourierTrackingEventListener {
    private static final Logger log = LoggerFactory.getLogger(StompCourierTrackingEventListener.class);
    private final SimpMessagingTemplate messaging;

    public StompCourierTrackingEventListener(SimpMessagingTemplate messaging) {
        this.messaging = messaging;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void publish(PendingCourierTrackingEvent pending) {
        var event = pending.event();
        messaging.convertAndSendToUser(pending.customerUserId().toString(),
                "/queue/orders/" + event.orderId() + "/tracking", event);
        log.info("tracking event published eventType={} orderId={} deliveryId={} courierId={} gpsTimestamp={}",
                event.type(), event.orderId(), event.deliveryId(), pending.courierId(),
                event.location() == null ? null : event.location().gpsTimestamp());
    }
}
