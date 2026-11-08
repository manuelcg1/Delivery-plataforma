package com.delivery.platform.tracking.application;

import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

@Component
public class CourierArrivalEventListener {
    private static final org.slf4j.Logger log=org.slf4j.LoggerFactory.getLogger(CourierArrivalEventListener.class);
    private final CourierNotificationService notifications;
    private final ArrivalNotificationOutbox outbox;
    public CourierArrivalEventListener(CourierNotificationService notifications, ArrivalNotificationOutbox outbox) {
        this.notifications=notifications;
        this.outbox=outbox;
    }

    @TransactionalEventListener(phase=TransactionPhase.BEFORE_COMMIT)
    public void persist(CourierArrivalEvent event) { outbox.enqueue(event); }

    @TransactionalEventListener(phase=TransactionPhase.AFTER_COMMIT)
    public void arrived(CourierArrivalEvent event) {
        try { notifications.arrival(event); }
        catch(RuntimeException error) {
            log.warn("Arrival realtime failed deliveryId={}; durable push remains queued",event.deliveryId(),error);
        }
    }
}
