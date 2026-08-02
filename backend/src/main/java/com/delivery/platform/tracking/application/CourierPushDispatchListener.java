package com.delivery.platform.tracking.application;

import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

@Component
public class CourierPushDispatchListener {
  private final CourierNotificationService notifications;
  public CourierPushDispatchListener(CourierNotificationService notifications){this.notifications=notifications;}

  @Async
  @TransactionalEventListener(phase=TransactionPhase.AFTER_COMMIT,fallbackExecution=true)
  public void dispatch(CourierNotificationService.PushDispatch event){notifications.dispatch(event);}
}
