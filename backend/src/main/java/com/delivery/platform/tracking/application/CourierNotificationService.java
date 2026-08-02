package com.delivery.platform.tracking.application;

import com.delivery.platform.identity.security.IdentityPrincipal;
import com.delivery.platform.tracking.realtime.RealtimeGateway;
import com.google.firebase.messaging.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.*;

/** Single dispatch boundary shared by realtime and background delivery. */
@Service
public class CourierNotificationService {
    public static final String ASSIGNMENT_EVENT = "NEW_DELIVERY_ASSIGNMENT";
    private static final Logger log = LoggerFactory.getLogger(CourierNotificationService.class);
    private final JdbcClient db;
    private final RealtimeGateway realtime;
    private final ApplicationEventPublisher events;

    public record PushDispatch(UUID tenant, UUID user, String eventId, Map<String, Object> payload) {}

    public CourierNotificationService(JdbcClient db, RealtimeGateway realtime, ApplicationEventPublisher events) {
        this.db = db;
        this.realtime = realtime;
        this.events = events;
    }

    @Transactional
    public void register(IdentityPrincipal principal, String token, String platform) {
        UUID courier = db.sql("select id from courier_profiles where tenant_id=:t and user_id=:u")
            .param("t", principal.tenantId()).param("u", principal.userId()).query(UUID.class).optional()
            .orElseThrow(() -> new IllegalStateException("Courier profile required"));
        db.sql("""
          insert into device_tokens(tenant_id,user_id,courier_id,token,platform)
          values(:t,:u,:c,:token,:platform)
          on conflict(tenant_id,token) do update set user_id=excluded.user_id,courier_id=excluded.courier_id,
            platform=excluded.platform,active=true,last_seen_at=now()
          """).param("t",principal.tenantId()).param("u",principal.userId()).param("c",courier)
          .param("token",token).param("platform",platform).update();
    }

    @Transactional
    public void unregister(IdentityPrincipal principal, String token) {
        db.sql("update device_tokens set active=false,last_seen_at=now() where tenant_id=:t and user_id=:u and token=:token")
          .param("t",principal.tenantId()).param("u",principal.userId()).param("token",token).update();
    }

    /** Database uniqueness makes retries idempotent. WebSocket and FCM carry the same event id. */
    @Transactional
    public void assignment(UUID tenant, UUID courierUser, Map<String,Object> details) {
        String deliveryId = Objects.toString(details.get("deliveryId"));
        String assignmentId = Objects.toString(details.get("assignmentId"),deliveryId);
        String key = ASSIGNMENT_EVENT + ":" + assignmentId;
        int inserted = db.sql("""
          insert into notifications(tenant_id,user_id,delivery_id,event_type,title,body,channel,status,sent_at,deduplication_key)
          values(:t,:u,cast(:d as uuid),:event,'Nuevo pedido',:body,'FCM','PENDING',null,:key)
          on conflict(tenant_id,user_id,deduplication_key) where deduplication_key is not null do nothing
          """).param("t",tenant).param("u",courierUser).param("d",deliveryId).param("event",ASSIGNMENT_EVENT)
          .param("body",body(details)).param("key",key).update();
        if (inserted == 0) {
            log.info("Duplicate notification skipped tenant={} user={} event={}",tenant,courierUser,key);
            return;
        }
        log.info("Notification persisted tenant={} user={} event={}",tenant,courierUser,key);
        Map<String,Object> payload = new HashMap<>(details);
        payload.put("type", ASSIGNMENT_EVENT);
        payload.put("eventId", key);
        events.publishEvent(new PushDispatch(tenant,courierUser,key,payload));
    }

    public void cancelled(UUID tenant, UUID courierUser, UUID deliveryId, String reason) {
        Map<String,Object> payload=Map.of("type","DELIVERY_ASSIGNMENT_CLOSED","deliveryId",deliveryId,"status",reason);
        events.publishEvent(new PushDispatch(tenant,courierUser,"closed:"+deliveryId,payload));
    }

    /** Reconciles closed assignments and retries transient push failures. */
    @Scheduled(fixedDelay = 5000)
    @Transactional
    public void reconcileAssignments() {
        List<Object[]> closed=db.sql("""
          select n.tenant_id,n.user_id,n.delivery_id,d.status from notifications n
          join deliveries d on d.id=n.delivery_id and d.tenant_id=n.tenant_id
          where n.event_type=:event and n.status in('PENDING','SENT') and d.status<>'ASSIGNED'
          for update of n skip locked
          """).param("event",ASSIGNMENT_EVENT).query((r,n)->new Object[]{r.getObject(1,UUID.class),
            r.getObject(2,UUID.class),r.getObject(3,UUID.class),r.getString(4)}).list();
        for(Object[] row:closed){
            cancelled((UUID)row[0],(UUID)row[1],(UUID)row[2],(String)row[3]);
            db.sql("update notifications set status='READ',read_at=now() where tenant_id=:t and user_id=:u and delivery_id=:d and event_type=:e")
              .param("t",row[0]).param("u",row[1]).param("d",row[2]).param("e",ASSIGNMENT_EVENT).update();
        }

        List<Object[]> failed = assignmentRows("""
          join notifications n on n.delivery_id=d.id and n.tenant_id=d.tenant_id and n.user_id=cp.user_id
          where d.status='ASSIGNED' and n.event_type=:event and n.status='FAILED' and n.attempt_count<5
            and n.last_attempt_at<now()-interval '30 seconds'
          for update of n skip locked
          """);
        for (Object[] row : failed) {
            Map<String,Object> retryPayload = payload(row);
            String eventId = Objects.toString(row[10]);
            retryPayload.put("type",ASSIGNMENT_EVENT);
            retryPayload.put("eventId",eventId);
            events.publishEvent(new PushDispatch((UUID)row[0],(UUID)row[1],eventId,retryPayload));
        }
    }

    private List<Object[]> assignmentRows(String condition) {
        return db.sql("""
          select d.tenant_id,cp.user_id,d.id,d.order_id,m.name,
            coalesce(u.first_name||' '||u.last_name,'Cliente'),coalesce(d.distance_km,0),
            coalesce(d.estimated_duration_minutes,0),o.currency||' '||o.total,
            coalesce(a.expires_at,now()+interval '5 minutes'),n.deduplication_key
          from deliveries d join orders o on o.id=d.order_id and o.tenant_id=d.tenant_id
          join merchants m on m.id=d.merchant_id and m.tenant_id=d.tenant_id
          join courier_profiles cp on cp.id=d.courier_id and cp.tenant_id=d.tenant_id
          left join users u on u.id=d.customer_id
          left join lateral(select expires_at from delivery_assignments da where da.tenant_id=d.tenant_id
            and da.delivery_id=d.id order by assigned_at desc limit 1)a on true
          """ + condition).param("event",ASSIGNMENT_EVENT)
          .query((r,n)->new Object[]{r.getObject(1,UUID.class),r.getObject(2,UUID.class),r.getObject(3,UUID.class),
            r.getObject(4,UUID.class),r.getString(5),r.getString(6),r.getBigDecimal(7),r.getInt(8),
            r.getString(9),r.getTimestamp(10).toInstant(),r.getString(11)}).list();
    }

    private Map<String,Object> payload(Object[] row) {
        Map<String,Object> result = new HashMap<>();
        result.put("deliveryId",row[2]); result.put("orderId",row[3]); result.put("merchantName",row[4]);
        result.put("customerName",row[5]); result.put("estimatedDistanceKm",row[6]);
        result.put("estimatedTimeMinutes",row[7]); result.put("total",row[8]); result.put("expiresAt",row[9]);
        return result;
    }

    void dispatch(PushDispatch request) {
        log.info("Publishing WebSocket tenant={} user={} event={}",request.tenant(),request.user(),request.eventId());
        realtime.tenant(request.tenant(),"courier/"+request.user(),Objects.toString(request.payload().get("type")),request.payload());
        log.info("Publishing Firebase Push tenant={} user={} event={}",request.tenant(),request.user(),request.eventId());
        sendFcm(request.tenant(),request.user(),request.eventId(),request.payload());
    }

    private void sendFcm(UUID tenant, UUID user, String eventId, Map<String,Object> values) {
        db.sql("update notifications set attempt_count=attempt_count+1,last_attempt_at=now() where tenant_id=:t and user_id=:u and deduplication_key=:k")
          .param("t",tenant).param("u",user).param("k",eventId).update();
        FirebaseMessaging messaging;
        try { messaging=FirebaseMessaging.getInstance(); } catch (IllegalStateException unavailable) {
            markFailed(tenant,user,eventId);
            log.warn("Firebase is not configured; event {} remains eligible for retry",eventId);
            return;
        }
        List<String> tokens=db.sql("select token from device_tokens where tenant_id=:t and user_id=:u and active=true")
          .param("t",tenant).param("u",user).query(String.class).list();
        if(tokens.isEmpty()) {
            markFailed(tenant,user,eventId);
            log.warn("No active device token tenant={} user={} event={}",tenant,user,eventId);
            return;
        }
        for(String token:tokens) try {
            Map<String,String> data=new HashMap<>(); values.forEach((k,v)->data.put(k,Objects.toString(v,"")));
            data.put("eventId",eventId);
            Message message=Message.builder().setToken(token).putAllData(data)
              .setAndroidConfig(AndroidConfig.builder().setPriority(AndroidConfig.Priority.HIGH).setTtl(900_000L).build())
              .setApnsConfig(ApnsConfig.builder().putHeader("apns-priority","10")
                .setAps(Aps.builder().setContentAvailable(true).build()).build()).build();
            messaging.send(message);
            log.info("Push delivered tenant={} user={} event={}",tenant,user,eventId);
            db.sql("update notifications set status='SENT',sent_at=now() where tenant_id=:t and user_id=:u and deduplication_key=:k")
              .param("t",tenant).param("u",user).param("k",eventId).update();
        } catch (FirebaseMessagingException error) {
            if (error.getMessagingErrorCode()==MessagingErrorCode.UNREGISTERED || error.getMessagingErrorCode()==MessagingErrorCode.INVALID_ARGUMENT)
                db.sql("update device_tokens set active=false where tenant_id=:t and token=:token")
                  .param("t",tenant).param("token",token).update();
            markFailed(tenant,user,eventId);
            log.warn("FCM dispatch failed tenant={} user={} event={} code={}",tenant,user,eventId,error.getMessagingErrorCode());
        } catch (RuntimeException error) {
            markFailed(tenant,user,eventId);
            log.error("Unexpected FCM dispatch failure tenant={} user={} event={}",tenant,user,eventId,error);
        }
    }

    private String body(Map<String,Object> p) {
        return String.join(" • ", Objects.toString(p.get("merchantName"),"Comercio"),
          Objects.toString(p.get("estimatedDistanceKm"),"--")+" km", Objects.toString(p.get("total"),""));
    }

    private void markFailed(UUID tenant, UUID user, String eventId) {
        db.sql("update notifications set status='FAILED' where tenant_id=:t and user_id=:u and deduplication_key=:k")
          .param("t",tenant).param("u",user).param("k",eventId).update();
    }
}
