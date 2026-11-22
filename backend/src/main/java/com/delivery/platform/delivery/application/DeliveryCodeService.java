package com.delivery.platform.delivery.application;

import com.delivery.platform.common.ApiException;
import com.delivery.platform.identity.security.IdentityPrincipal;
import com.delivery.platform.tracking.realtime.RealtimeGateway;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.Instant;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Código secreto de 5 caracteres que el cliente entrega al repartidor al recibir el pedido.
 * Solo el cliente puede leerlo; el repartidor solo puede validarlo, con intentos limitados.
 */
@Service
public class DeliveryCodeService {
    /** Sin caracteres ambiguos (0/O, 1/I/L, 2/Z, 5/S, 8/B). */
    public static final String ALPHABET = "ACDEFGHJKMNPQRTUVWXY34679";
    public static final int CODE_LENGTH = 5;
    public static final int MAX_FAILED_ATTEMPTS = 5;
    public static final int LOCK_MINUTES = 10;
    private static final SecureRandom RANDOM = new SecureRandom();

    public record Verification(boolean verified, Instant verifiedAt) {}

    private record StoredCode(String code, int failedAttempts, Instant lockedUntil, Instant validatedAt) {}

    private record CourierDelivery(UUID orderId, UUID merchantId, String status, String type) {}

    private final JdbcClient db;
    private final RealtimeGateway realtime;

    public DeliveryCodeService(JdbcClient db, RealtimeGateway realtime) {
        this.db = db;
        this.realtime = realtime;
    }

    public static String generate() {
        return random(CODE_LENGTH);
    }

    static String random(int length) {
        StringBuilder value = new StringBuilder(length);
        for (int i = 0; i < length; i++) value.append(ALPHABET.charAt(RANDOM.nextInt(ALPHABET.length())));
        return value.toString();
    }

    /** Número de pedido corto y público, distinto del código secreto de entrega. */
    public static String orderNumber() {
        return "CK-" + random(6);
    }

    public static String normalize(String code) {
        return code == null ? "" : code.replaceAll("[\\s-]", "").toUpperCase(Locale.ROOT);
    }

    static boolean matches(String expected, String provided) {
        return MessageDigest.isEqual(expected.getBytes(StandardCharsets.UTF_8),
                normalize(provided).getBytes(StandardCharsets.UTF_8));
    }

    public Verification status(IdentityPrincipal principal, UUID deliveryId) {
        CourierDelivery delivery = courierDelivery(principal, deliveryId);
        Instant validatedAt = db.sql("select validated_at from order_delivery_codes where order_id=:o and tenant_id=:t")
                .param("o", delivery.orderId()).param("t", principal.tenantId())
                .query((r, n) -> r.getTimestamp(1) == null ? null : r.getTimestamp(1).toInstant())
                .optional().orElse(null);
        return new Verification(validatedAt != null, validatedAt);
    }

    /** Los intentos fallidos deben persistir aunque la respuesta sea un error. */
    @Transactional(noRollbackFor = ApiException.class)
    public Verification verify(IdentityPrincipal principal, UUID deliveryId, String provided) {
        CourierDelivery delivery = courierDelivery(principal, deliveryId);
        if (!"ARRIVED_AT_CUSTOMER".equals(delivery.status()))
            throw new ApiException(HttpStatus.CONFLICT, "DELIVERY_CODE_NOT_ALLOWED",
                    "Primero confirma que llegaste al destino del cliente.");
        StoredCode stored = db.sql("select code,failed_attempts,locked_until,validated_at from order_delivery_codes where order_id=:o and tenant_id=:t for update")
                .param("o", delivery.orderId()).param("t", principal.tenantId())
                .query((r, n) -> new StoredCode(r.getString(1), r.getInt(2),
                        r.getTimestamp(3) == null ? null : r.getTimestamp(3).toInstant(),
                        r.getTimestamp(4) == null ? null : r.getTimestamp(4).toInstant()))
                .optional().orElseThrow(() -> new ApiException(HttpStatus.CONFLICT, "DELIVERY_CODE_MISSING",
                        "Este pedido no tiene código de entrega. Contacta al comercio."));
        if (stored.validatedAt() != null) return new Verification(true, stored.validatedAt());
        if (stored.lockedUntil() != null && stored.lockedUntil().isAfter(Instant.now()))
            throw new ApiException(HttpStatus.TOO_MANY_REQUESTS, "DELIVERY_CODE_LOCKED",
                    "Demasiados intentos. Espera " + LOCK_MINUTES + " minutos o contacta al comercio.");
        if (normalize(provided).length() != CODE_LENGTH || !matches(stored.code(), provided)) {
            int failed = stored.failedAttempts() + 1;
            boolean lock = failed >= MAX_FAILED_ATTEMPTS;
            db.sql("update order_delivery_codes set failed_attempts=:f,locked_until=case when :lock then now()+make_interval(mins=>:m) else locked_until end where order_id=:o and tenant_id=:t")
                    .param("f", lock ? 0 : failed).param("lock", lock).param("m", LOCK_MINUTES)
                    .param("o", delivery.orderId()).param("t", principal.tenantId()).update();
            audit(principal, deliveryId, "DELIVERY_CODE_FAILED");
            if (lock)
                throw new ApiException(HttpStatus.TOO_MANY_REQUESTS, "DELIVERY_CODE_LOCKED",
                        "Demasiados intentos. Espera " + LOCK_MINUTES + " minutos o contacta al comercio.");
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "DELIVERY_CODE_INVALID",
                    "Código incorrecto. Te quedan " + (MAX_FAILED_ATTEMPTS - failed) + " intentos.");
        }
        Instant now = Instant.now();
        db.sql("update order_delivery_codes set validated_at=now(),validated_by=:u,failed_attempts=0,locked_until=null where order_id=:o and tenant_id=:t")
                .param("u", principal.userId()).param("o", delivery.orderId()).param("t", principal.tenantId()).update();
        audit(principal, deliveryId, "DELIVERY_CODE_VALIDATED");
        if (realtime != null) {
            Map<String, Object> payload = Map.of("deliveryId", deliveryId, "orderId", delivery.orderId());
            realtime.delivery(principal.tenantId(), deliveryId, "DeliveryCodeValidated", payload);
            realtime.tenant(principal.tenantId(), "merchant/" + delivery.merchantId(), "ORDER_UPDATED", payload);
        }
        return new Verification(true, now);
    }

    private CourierDelivery courierDelivery(IdentityPrincipal principal, UUID deliveryId) {
        return db.sql("""
                select d.order_id,d.merchant_id,d.status,d.delivery_type from deliveries d
                join courier_profiles c on c.id=d.courier_id and c.tenant_id=d.tenant_id
                where d.id=:d and d.tenant_id=:t and c.user_id=:u
                """).param("d", deliveryId).param("t", principal.tenantId()).param("u", principal.userId())
                .query((r, n) -> new CourierDelivery(r.getObject(1, UUID.class), r.getObject(2, UUID.class),
                        r.getString(3), r.getString(4)))
                .optional().orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "DELIVERY_NOT_FOUND",
                        "Entrega no encontrada"));
    }

    private void audit(IdentityPrincipal principal, UUID deliveryId, String action) {
        db.sql("insert into audit_logs(tenant_id,user_id,action,entity_type,entity_id) values(:t,:u,:a,'DELIVERY',:d)")
                .param("t", principal.tenantId()).param("u", principal.userId()).param("a", action).param("d", deliveryId).update();
    }
}
