package com.delivery.platform.tracking.application;

import com.google.firebase.messaging.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import java.util.*;
import java.util.concurrent.*;
import com.google.api.core.ApiFuture;

/** Transport only: the caller owns persistence, claims and retries. */
@Service
public class FirebasePushSender {
    private static final Logger log = LoggerFactory.getLogger(FirebasePushSender.class);
    private final JdbcClient db;
    public FirebasePushSender(JdbcClient db) { this.db = db; }
    public record Result(boolean accepted, String error) {}

    public Result send(UUID tenant, UUID user, String eventId, Map<String,Object> payload) {
        FirebaseMessaging messaging;
        try { messaging = FirebaseMessaging.getInstance(); }
        catch (IllegalStateException unavailable) { return new Result(false, "FIREBASE_NOT_CONFIGURED"); }
        List<String> tokens = db.sql("select token from device_tokens where tenant_id=:t and user_id=:u and active=true")
            .param("t",tenant).param("u",user).query(String.class).list();
        if (tokens.isEmpty()) return new Result(false, "NO_ACTIVE_DEVICE_TOKEN");
        boolean accepted = false;
        String errorCode = null;
        long deadline=System.nanoTime()+TimeUnit.SECONDS.toNanos(60);
        for (String token : tokens) {
            ApiFuture<String> sending=null;
            try {
                long remaining=deadline-System.nanoTime();
                if(remaining<=0) { errorCode="FCM_TIMEOUT"; break; }
                sending=messaging.sendAsync(message(token, eventId, payload));
                sending.get(remaining,TimeUnit.NANOSECONDS);
                accepted = true;
            } catch (TimeoutException timeout) {
                if(sending!=null) sending.cancel(true);
                errorCode="FCM_TIMEOUT";
                break;
            } catch (InterruptedException interrupted) {
                if(sending!=null) sending.cancel(true);
                Thread.currentThread().interrupt();
                errorCode="DISPATCH_INTERRUPTED";
                break;
            } catch (ExecutionException failure) {
                if(!(failure.getCause() instanceof FirebaseMessagingException error)) {
                    errorCode="FCM_ERROR";
                    continue;
                }
                errorCode = Objects.toString(error.getMessagingErrorCode(), "FCM_ERROR");
                if (error.getMessagingErrorCode() == MessagingErrorCode.UNREGISTERED) {
                    db.sql("update device_tokens set active=false where tenant_id=:t and user_id=:u and token=:token")
                        .param("t",tenant).param("u",user).param("token",token).update();
                }
                log.warn("FCM rejected event={} code={}", eventId, errorCode);
            }
        }
        // One accepted device completes the user notification; do not resend to successful devices.
        return new Result(accepted, errorCode);
    }

    /** Categoría iOS registrada en la app para mostrar los botones Aceptar/Rechazar. */
    static final String COURIER_OFFER_CATEGORY = "CERKA_NEW_DELIVERY";

    /**
     * Las ofertas al repartidor se envían solo con datos en Android: si FCM incluye un bloque
     * "notification", el sistema la muestra sin botones y la app no puede añadir ACEPTAR/RECHAZAR.
     * El cierre de una oferta también es silencioso para no mostrar avisos vacíos.
     */
    static boolean dataOnly(String type) {
        return CourierNotificationService.ASSIGNMENT_EVENT.equals(type) || "DELIVERY_ASSIGNMENT_CLOSED".equals(type);
    }

    static String title(Map<String,String> data) {
        if (CourierNotificationService.ASSIGNMENT_EVENT.equals(data.get("type")))
            return "Nuevo pedido · " + data.getOrDefault("merchantName", "Comercio");
        return data.getOrDefault("title", "Cerka");
    }

    static String body(Map<String,String> data) {
        if (CourierNotificationService.ASSIGNMENT_EVENT.equals(data.get("type")))
            return data.getOrDefault("customerName", "Cliente") + " · " + data.getOrDefault("estimatedDistanceKm", "--")
                + " km · " + data.getOrDefault("total", "");
        return data.getOrDefault("body", "");
    }

    static Message message(String token, String eventId, Map<String,Object> payload) {
        Map<String,String> data = new HashMap<>();
        payload.forEach((key,value) -> data.put(key,Objects.toString(value,"")));
        data.put("eventId",eventId);
        String type = data.get("type");
        boolean arrival = "COURIER_ARRIVED".equals(type);
        Message.Builder builder = Message.builder().setToken(token).putAllData(data);
        if (dataOnly(type)) {
            boolean offer = CourierNotificationService.ASSIGNMENT_EVENT.equals(type);
            Aps.Builder aps = Aps.builder().setContentAvailable(true);
            if (offer) aps.setAlert(ApsAlert.builder().setTitle(title(data)).setBody(body(data)).build())
                .setSound("default").setCategory(COURIER_OFFER_CATEGORY);
            return builder
                .setAndroidConfig(AndroidConfig.builder().setPriority(AndroidConfig.Priority.HIGH).setTtl(offer ? 900_000L : 300_000L).build())
                .setApnsConfig(ApnsConfig.builder().putHeader("apns-priority", offer ? "10" : "5")
                    .putHeader("apns-push-type", offer ? "alert" : "background")
                    .putHeader("apns-collapse-id",eventId).setAps(aps.build()).build()).build();
        }
        return builder
            .setNotification(Notification.builder().setTitle(title(data)).setBody(body(data)).build())
            .setAndroidConfig(AndroidConfig.builder().setPriority(AndroidConfig.Priority.HIGH).setTtl(900_000L)
                .setNotification(AndroidNotification.builder()
                    .setChannelId(arrival ? "CERKA_ORDER_ARRIVAL" : data.getOrDefault("channel", "CERKA_NEW_DELIVERY"))
                    .setTag(eventId).setSound("default").setDefaultVibrateTimings(true).build()).build())
            .setApnsConfig(ApnsConfig.builder().putHeader("apns-priority","10")
                .putHeader("apns-collapse-id",eventId)
                .setAps(Aps.builder().setSound("default").setContentAvailable(true).build()).build()).build();
    }
}
