package com.delivery.platform.tracking.application;

import io.micrometer.core.instrument.MeterRegistry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.*;

/** Durable arrival notifications. Network calls never hold the arrival transaction open. */
@Service
public class ArrivalNotificationOutbox {
    private static final Logger log = LoggerFactory.getLogger(ArrivalNotificationOutbox.class);
    private final JdbcClient db;
    private final TransactionTemplate transaction;
    private final FirebasePushSender sender;
    private final MeterRegistry metrics;
    private record Claim(UUID id, UUID tenant, UUID user, UUID delivery, UUID order,
                         String eventId, String title, String body, int attempt, UUID token) {}

    public ArrivalNotificationOutbox(JdbcClient db, PlatformTransactionManager manager,
                                     FirebasePushSender sender, MeterRegistry metrics) {
        this.db=db; this.transaction=new TransactionTemplate(manager); this.sender=sender; this.metrics=metrics;
    }

    @Transactional(propagation=Propagation.MANDATORY)
    public void enqueue(CourierArrivalEvent arrival) {
        // Lock the aggregate as well as enforcing the existing unique deduplication index.
        db.sql("select id from deliveries where tenant_id=:t and id=:d and customer_id=:u and order_id=:o for update")
            .param("t",arrival.tenantId()).param("d",arrival.deliveryId()).param("u",arrival.customerId())
            .param("o",arrival.orderId()).query(UUID.class).single();
        db.sql("""
            insert into notifications(tenant_id,user_id,delivery_id,event_type,title,body,channel,status,deduplication_key)
            select :t,:u,:d,'COURIER_ARRIVED','¡Llegó tu pedido!',
              'Tu repartidor ya se encuentra en el punto de entrega.','FCM','PENDING',:key
            where not exists(select 1 from notifications where tenant_id=:t and user_id=:u and deduplication_key=:key)
            """).param("t",arrival.tenantId()).param("u",arrival.customerId()).param("d",arrival.deliveryId())
            .param("key","COURIER_ARRIVED:"+arrival.deliveryId()).update();
    }

    @Scheduled(fixedDelayString="${notifications.arrival.poll-delay-ms:5000}",scheduler="arrivalNotificationScheduler")
    public void processPending() {
        for (int i=0;i<20;i++) {
            Claim claim=transaction.execute(s -> claimNext());
            if (claim==null) return;
            FirebasePushSender.Result result;
            try { result=sender.send(claim.tenant(),claim.user(),claim.eventId(),payload(claim)); }
            catch (RuntimeException error) {
                log.error("Arrival push failed event={} error={}",claim.eventId(),error.getClass().getSimpleName());
                result=new FirebasePushSender.Result(false,"DISPATCH_ERROR");
            }
            FirebasePushSender.Result outcome=result;
            transaction.executeWithoutResult(s -> complete(claim,outcome));
        }
    }

    private Claim claimNext() {
        Timestamp now=Timestamp.from(Instant.now());
        Timestamp oldest=Timestamp.from(Instant.now().minusSeconds(900));
        db.sql("""
            update notifications set status='FAILED',last_error=case when attempt_count>=5 then 'RETRY_LIMIT' else 'EXPIRED' end,
              claim_token=null,claim_until=null
            where event_type='COURIER_ARRIVED' and status in('PENDING','FAILED')
              and (attempt_count>=5 or created_at<:oldest) and (claim_until is null or claim_until<:now)
              and (last_error is null or last_error not in('RETRY_LIMIT','EXPIRED'))
            """).param("oldest",oldest).param("now",now).update();
        // SKIP LOCKED allows independent workers; the lease survives a process restart.
        UUID id=db.sql("""
            select id from notifications where event_type='COURIER_ARRIVED' and status in('PENDING','FAILED')
              and attempt_count<5 and created_at>=:oldest
              and (next_attempt_at is null or next_attempt_at<=:now)
              and (claim_until is null or claim_until<:now)
            order by created_at limit 1 for update skip locked
            """).param("oldest",oldest).param("now",now).query(UUID.class).optional().orElse(null);
        if (id==null) return null;
        UUID token=UUID.randomUUID();
        db.sql("update notifications set claim_token=:token,claim_until=:until,attempt_count=attempt_count+1,last_attempt_at=:now where id=:id")
            .param("token",token).param("until",Timestamp.from(Instant.now().plusSeconds(120)))
            .param("now",now).param("id",id).update();
        return db.sql("""
            select n.tenant_id,n.user_id,n.delivery_id,d.order_id,n.deduplication_key,n.title,n.body,n.attempt_count
            from notifications n join deliveries d on d.id=n.delivery_id and d.tenant_id=n.tenant_id where n.id=:id
            """).param("id",id).query((r,n)->new Claim(id,r.getObject(1,UUID.class),r.getObject(2,UUID.class),
                r.getObject(3,UUID.class),r.getObject(4,UUID.class),r.getString(5),r.getString(6),r.getString(7),r.getInt(8),token)).single();
    }

    private Map<String,Object> payload(Claim c) {
        return Map.of("type","COURIER_ARRIVED","deliveryId",c.delivery(),"orderId",c.order(),
            "status","ARRIVED_AT_CUSTOMER","deliveryStatus","ARRIVED_AT_CUSTOMER",
            "route","/orders/"+c.order(),"title",c.title(),"body",c.body());
    }

    private void complete(Claim c,FirebasePushSender.Result result) {
        Timestamp now=Timestamp.from(Instant.now());
        int changed=db.sql("""
            update notifications set status=:status,sent_at=:sent,last_error=:error,
              next_attempt_at=:next,claim_token=null,claim_until=null
            where tenant_id=:t and id=:id and claim_token=:token
            """).param("status",result.accepted()?"SENT":"FAILED").param("sent",result.accepted()?now:null)
            .param("error",result.error()).param("next",Timestamp.from(Instant.now().plusSeconds(30L << (c.attempt()-1))))
            .param("t",c.tenant()).param("id",c.id()).param("token",c.token()).update();
        if(changed==0) return; // A stale worker cannot overwrite a newer attempt.
        if(result.accepted()) {
            db.sql("update deliveries set arrival_notified_at=:now where tenant_id=:t and id=:d and arrival_notified_at is null")
                .param("now",now).param("t",c.tenant()).param("d",c.delivery()).update();
            db.sql("update courier_arrival_audit set notified_at=:now where tenant_id=:t and delivery_id=:d and notified_at is null")
                .param("now",now).param("t",c.tenant()).param("d",c.delivery()).update();
        }
        metrics.counter(result.accepted()?"courier_arrival_push_sent_total":"courier_arrival_push_failed_total").increment();
        log.info("Arrival push event={} attempt={} acceptedByFcm={} error={}",c.eventId(),c.attempt(),result.accepted(),result.error());
    }
}
