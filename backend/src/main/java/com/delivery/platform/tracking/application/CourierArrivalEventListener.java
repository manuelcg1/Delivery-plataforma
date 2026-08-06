package com.delivery.platform.tracking.application;

import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

@Component
public class CourierArrivalEventListener {
    private final CourierNotificationService notifications;
    public CourierArrivalEventListener(CourierNotificationService notifications) { this.notifications=notifications; }

    @TransactionalEventListener(phase=TransactionPhase.AFTER_COMMIT)
    public void arrived(CourierArrivalEvent event) { notifications.arrival(event); }
}
