package com.delivery.platform.tracking.application;

import com.delivery.platform.common.ApiException;
import com.delivery.platform.identity.security.IdentityPrincipal;
import com.delivery.platform.tracking.infrastructure.ProofStorage;
import com.delivery.platform.tracking.realtime.RealtimeGateway;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.security.SecureRandom;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.UUID;

@Service
public class CourierInteractionService {
    public record Proof(UUID id, UUID deliveryId, String proofType, String url, String comments, Instant createdAt) {}
    public record TemporaryCode(String value, Instant expiresAt) {}
    public record Message(UUID id, UUID deliveryId, UUID senderId, String senderType, String channel, String message, Instant createdAt) {}
    public record Notification(UUID id, UUID deliveryId, String eventType, String title, String body, String status, Instant createdAt) {}

    private final JdbcClient db;
    private final ProofStorage storage;
    private final PasswordEncoder passwords;
    private final RealtimeGateway realtime;
    private final SecureRandom random = new SecureRandom();

    public CourierInteractionService(JdbcClient db, ProofStorage storage, PasswordEncoder passwords, RealtimeGateway realtime) {
        this.db = db;
        this.storage = storage;
        this.passwords = passwords;
        this.realtime = realtime;
    }

    @Transactional
    public Proof upload(IdentityPrincipal principal, UUID orderId, String type, String comments, MultipartFile file) {
        UUID deliveryId = delivery(principal, orderId);
        if (!List.of("PHOTO", "SIGNATURE").contains(type))
            throw error(HttpStatus.BAD_REQUEST, "PROOF_TYPE_INVALID", "Tipo de prueba no válido");
        String key = storage.put(principal.tenantId(), deliveryId, type, file);
        UUID id = UUID.randomUUID();
        db.sql("insert into proof_of_delivery(id,tenant_id,delivery_id,proof_type,object_key,comments,created_by) values(:i,:t,:d,:p,:o,:c,:u)")
                .param("i", id).param("t", principal.tenantId()).param("d", deliveryId).param("p", type)
                .param("o", key).param("c", comments).param("u", principal.userId()).update();
        event(principal, deliveryId, "ProofUploaded");
        return new Proof(id, deliveryId, type, storage.signedUrl(key), comments, Instant.now());
    }

    public List<Proof> proofs(IdentityPrincipal principal, UUID orderId) {
        UUID deliveryId = delivery(principal, orderId);
        return db.sql("select * from proof_of_delivery where tenant_id=:t and delivery_id=:d order by created_at desc")
                .param("t", principal.tenantId()).param("d", deliveryId)
                .query((r, n) -> new Proof(r.getObject("id", UUID.class), deliveryId, r.getString("proof_type"),
                        storage.signedUrl(r.getString("object_key")), r.getString("comments"), r.getTimestamp("created_at").toInstant())).list();
    }

    @Transactional
    public TemporaryCode createOtp(IdentityPrincipal principal, UUID orderId) {
        UUID deliveryId = delivery(principal, orderId);
        String code = "%06d".formatted(random.nextInt(1_000_000));
        Instant expires = Instant.now().plus(10, ChronoUnit.MINUTES);
        db.sql("insert into otp_codes(tenant_id,delivery_id,code_hash,expires_at) values(:t,:d,:h,:e)")
                .param("t", principal.tenantId()).param("d", deliveryId).param("h", passwords.encode(code)).param("e", expires).update();
        return new TemporaryCode(code, expires);
    }

    @Transactional
    public void validateOtp(IdentityPrincipal principal, UUID orderId, String code) {
        UUID deliveryId = delivery(principal, orderId);
        Object[] otp = db.sql("select id,code_hash from otp_codes where tenant_id=:t and delivery_id=:d and validated_at is null and expires_at>now() order by created_at desc limit 1")
                .param("t", principal.tenantId()).param("d", deliveryId)
                .query((r, n) -> new Object[]{r.getObject("id", UUID.class), r.getString("code_hash")}).optional()
                .orElseThrow(() -> error(HttpStatus.CONFLICT, "OTP_EXPIRED", "El código OTP no existe o expiró"));
        db.sql("update otp_codes set attempts=attempts+1 where id=:i").param("i", otp[0]).update();
        if (!passwords.matches(code, (String) otp[1]))
            throw error(HttpStatus.CONFLICT, "OTP_INVALID", "El código OTP es incorrecto");
        db.sql("update otp_codes set validated_at=now() where id=:i").param("i", otp[0]).update();
        recordProof(principal, deliveryId, "OTP", "OTP validado");
        event(principal, deliveryId, "OTPValidated");
    }

    @Transactional
    public TemporaryCode createQr(IdentityPrincipal principal, UUID orderId) {
        UUID deliveryId = delivery(principal, orderId);
        String token = UUID.randomUUID().toString();
        Instant expires = Instant.now().plus(24, ChronoUnit.HOURS);
        db.sql("insert into qr_codes(tenant_id,delivery_id,token_hash,expires_at) values(:t,:d,:h,:e)")
                .param("t", principal.tenantId()).param("d", deliveryId).param("h", passwords.encode(token)).param("e", expires).update();
        return new TemporaryCode(token, expires);
    }

    @Transactional
    public void scanQr(IdentityPrincipal principal, UUID orderId, String token) {
        UUID deliveryId = delivery(principal, orderId);
        Object[] qr = db.sql("select id,token_hash from qr_codes where tenant_id=:t and delivery_id=:d and scanned_at is null and expires_at>now() order by created_at desc limit 1")
                .param("t", principal.tenantId()).param("d", deliveryId)
                .query((r, n) -> new Object[]{r.getObject("id", UUID.class), r.getString("token_hash")}).optional()
                .orElseThrow(() -> error(HttpStatus.CONFLICT, "QR_EXPIRED", "El código QR no existe o expiró"));
        if (!passwords.matches(token, (String) qr[1]))
            throw error(HttpStatus.CONFLICT, "QR_INVALID", "El código QR es incorrecto");
        db.sql("update qr_codes set scanned_at=now() where id=:i").param("i", qr[0]).update();
        recordProof(principal, deliveryId, "QR", "QR escaneado");
        event(principal, deliveryId, "QRScanned");
    }

    @Transactional
    public Message message(IdentityPrincipal principal, UUID deliveryId, String channel, String text) {
        access(principal, deliveryId);
        if (!List.of("CUSTOMER_COURIER", "MERCHANT_COURIER").contains(channel))
            throw error(HttpStatus.BAD_REQUEST, "CHAT_CHANNEL_INVALID", "Canal de chat no válido");
        String senderType = senderType(principal, deliveryId);
        UUID id = UUID.randomUUID();
        db.sql("insert into chat_messages(id,tenant_id,delivery_id,sender_id,sender_type,channel,message) values(:i,:t,:d,:u,:s,:c,:m)")
                .param("i", id).param("t", principal.tenantId()).param("d", deliveryId).param("u", principal.userId())
                .param("s", senderType).param("c", channel).param("m", text).update();
        Message message = new Message(id, deliveryId, principal.userId(), senderType, channel, text, Instant.now());
        realtime.delivery(principal.tenantId(), deliveryId, "ChatMessageReceived", message);
        return message;
    }

    public List<Message> history(IdentityPrincipal principal, UUID deliveryId, String channel) {
        access(principal, deliveryId);
        return db.sql("select * from chat_messages where tenant_id=:t and delivery_id=:d and (cast(:c as varchar) is null or channel=:c) order by created_at")
                .param("t", principal.tenantId()).param("d", deliveryId).param("c", channel)
                .query((r, n) -> new Message(r.getObject("id", UUID.class), deliveryId, r.getObject("sender_id", UUID.class),
                        r.getString("sender_type"), r.getString("channel"), r.getString("message"), r.getTimestamp("created_at").toInstant())).list();
    }

    public List<Notification> notifications(IdentityPrincipal principal) {
        return db.sql("""
                select n.* from notifications n
                where n.tenant_id=:t and n.user_id=:u
                  and (n.event_type not in ('COURIER_ASSIGNED','COURIER_ASSIGNMENT_PENDING')
                    or exists(
                      select 1 from delivery_assignments da
                      join courier_profiles cp on cp.id=da.courier_id and cp.tenant_id=da.tenant_id
                      join deliveries d on d.id=da.delivery_id and d.tenant_id=da.tenant_id
                      where da.delivery_id=n.delivery_id and da.tenant_id=n.tenant_id
                        and cp.user_id=:u and da.status in ('PENDING','ACCEPTED')
                        and d.courier_id=da.courier_id
                        and d.status not in ('DELIVERED','CANCELLED','FAILED','REJECTED','EXPIRED')
                        and (da.status='ACCEPTED' or da.expires_at>now())
                        and n.created_at>=da.assigned_at
                    ))
                order by n.created_at desc limit 100
                """)
                .param("t", principal.tenantId()).param("u", principal.userId())
                .query((r, n) -> new Notification(r.getObject("id", UUID.class), r.getObject("delivery_id", UUID.class),
                        r.getString("event_type"), r.getString("title"), r.getString("body"), r.getString("status"),
                        r.getTimestamp("created_at").toInstant())).list();
    }

    private UUID delivery(IdentityPrincipal principal, UUID orderId) {
        return db.sql("select id from deliveries where tenant_id=:t and order_id=:o and (customer_id=:u or courier_id in(select id from courier_profiles where user_id=:u and tenant_id=:t) or :admin) order by created_at desc limit 1")
                .param("t", principal.tenantId()).param("o", orderId).param("u", principal.userId())
                .param("admin", principal.permissions().contains("TRACKING_ADMIN") || principal.permissions().contains("DELIVERY_ADMIN"))
                .query(UUID.class).optional().orElseThrow(() -> error(HttpStatus.NOT_FOUND, "DELIVERY_NOT_FOUND", "Entrega no encontrada"));
    }

    private void access(IdentityPrincipal principal, UUID deliveryId) {
        int count = db.sql("select count(*) from deliveries where tenant_id=:t and id=:d and (customer_id=:u or courier_id in(select id from courier_profiles where user_id=:u and tenant_id=:t) or :admin)")
                .param("t", principal.tenantId()).param("d", deliveryId).param("u", principal.userId())
                .param("admin", principal.permissions().contains("TRACKING_ADMIN") || principal.permissions().contains("DELIVERY_ADMIN")).query(Integer.class).single();
        if (count == 0) throw error(HttpStatus.NOT_FOUND, "DELIVERY_NOT_FOUND", "Entrega no encontrada");
    }

    private String senderType(IdentityPrincipal principal, UUID deliveryId) {
        if (principal.permissions().contains("TRACKING_ADMIN")) return "ADMIN";
        int courier = db.sql("select count(*) from deliveries d join courier_profiles c on c.id=d.courier_id where d.id=:d and c.user_id=:u")
                .param("d", deliveryId).param("u", principal.userId()).query(Integer.class).single();
        return courier > 0 ? "COURIER" : "CUSTOMER";
    }

    private void recordProof(IdentityPrincipal principal, UUID deliveryId, String type, String comment) {
        db.sql("insert into proof_of_delivery(tenant_id,delivery_id,proof_type,comments,created_by) values(:t,:d,:p,:c,:u)")
                .param("t", principal.tenantId()).param("d", deliveryId).param("p", type).param("c", comment).param("u", principal.userId()).update();
    }

    private void event(IdentityPrincipal principal, UUID deliveryId, String type) {
        db.sql("insert into tracking_events(tenant_id,delivery_id,event_type,payload) values(:t,:d,:e,'{}')")
                .param("t", principal.tenantId()).param("d", deliveryId).param("e", type).update();
        realtime.delivery(principal.tenantId(), deliveryId, type, java.util.Map.of("deliveryId", deliveryId));
    }

    private ApiException error(HttpStatus status, String code, String message) {
        return new ApiException(status, code, message);
    }
}
