package com.delivery.platform.tracking.realtime;

import com.delivery.platform.identity.security.IdentityPrincipal;
import com.delivery.platform.identity.security.IdentityPrincipalLoader;
import com.delivery.platform.identity.security.JwtService;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.messaging.Message;
import org.springframework.messaging.MessageChannel;
import org.springframework.messaging.simp.SimpMessageType;
import org.springframework.messaging.simp.config.ChannelRegistration;
import org.springframework.messaging.simp.config.MessageBrokerRegistry;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.messaging.support.ChannelInterceptor;
import org.springframework.messaging.support.MessageHeaderAccessor;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.web.socket.config.annotation.EnableWebSocketMessageBroker;
import org.springframework.web.socket.config.annotation.StompEndpointRegistry;
import org.springframework.web.socket.config.annotation.WebSocketMessageBrokerConfigurer;

import java.util.UUID;
import java.util.stream.Stream;

@Configuration
@EnableWebSocketMessageBroker
public class WebSocketConfig implements WebSocketMessageBrokerConfigurer {
    private final String[] origins;
    private final JdbcClient db;
    private final JwtService jwt;
    private final IdentityPrincipalLoader principals;
    private final java.util.concurrent.ConcurrentMap<String,IdentityPrincipal> sessions=new java.util.concurrent.ConcurrentHashMap<>();

    public WebSocketConfig(@Value("${CORS_ALLOWED_ORIGINS:http://localhost:3000}") String origins,
                           JdbcClient db, JwtService jwt, IdentityPrincipalLoader principals) {
        this.origins = java.util.Arrays.stream(origins.split(",")).map(String::trim).toArray(String[]::new);
        this.db = db;
        this.jwt = jwt;
        this.principals = principals;
    }

    @Override
    public void configureMessageBroker(MessageBrokerRegistry registry) {
        registry.enableSimpleBroker("/topic", "/queue");
        registry.setApplicationDestinationPrefixes("/app");
        registry.setUserDestinationPrefix("/user");
    }

    @Override
    public void registerStompEndpoints(StompEndpointRegistry registry) {
        registry.addEndpoint("/api/v1/realtime").setAllowedOrigins(origins);
    }

    @Override
    public void configureClientInboundChannel(ChannelRegistration registration) {
        registration.interceptors(new ChannelInterceptor() {
            @Override
            public Message<?> preSend(Message<?> message, MessageChannel channel) {
                StompHeaderAccessor accessor = MessageHeaderAccessor.getAccessor(message, StompHeaderAccessor.class);
                if (accessor == null) return message;
                if (accessor.getMessageType() == SimpMessageType.MESSAGE)
                    throw new AccessDeniedException("El canal de eventos no admite publicaciones del cliente");
                if (accessor.getMessageType() == SimpMessageType.CONNECT) {
                    authenticate(accessor);
                    if (accessor.getSessionId()!=null) sessions.put(accessor.getSessionId(),principal(accessor));
                }
                if (accessor.getMessageType() == SimpMessageType.DISCONNECT && accessor.getSessionId()!=null)
                    sessions.remove(accessor.getSessionId());
                if (accessor.getMessageType() != SimpMessageType.SUBSCRIBE) return message;
                authorizeSubscription(accessor);
                return message;
            }
        });
    }

    @org.springframework.context.event.EventListener
    public void disconnected(org.springframework.web.socket.messaging.SessionDisconnectEvent event) {
        sessions.remove(event.getSessionId());
    }

    @Override
    public void configureClientOutboundChannel(ChannelRegistration registration) {
        registration.interceptors(new ChannelInterceptor() {
            @Override public Message<?> preSend(Message<?> message,MessageChannel channel) {
                var header=StompHeaderAccessor.wrap(message);
                String destination=header.getDestination();
                if (header.getMessageType()!=SimpMessageType.MESSAGE || destination==null
                        || !destination.startsWith("/topic/tenants/") || !destination.contains("/merchant/")) return message;
                var connected=header.getSessionId()==null?null:sessions.get(header.getSessionId());
                if (connected==null) return null;
                // The simple broker delivers per session. Recheck current identity and merchant
                // membership so suspension/revocation also applies to existing subscriptions.
                var check=StompHeaderAccessor.create(org.springframework.messaging.simp.stomp.StompCommand.SUBSCRIBE);
                check.setDestination(destination);
                check.setUser(new UsernamePasswordAuthenticationToken(connected,null,java.util.List.of()));
                try { authorizeSubscription(check); return message; }
                catch (AccessDeniedException denied) { return null; }
            }
        });
    }

    void authenticate(StompHeaderAccessor accessor) {
        if (principal(accessor) != null) return;
        String authorization = accessor.getFirstNativeHeader("Authorization");
        if (authorization == null || !authorization.startsWith("Bearer ")) {
            throw new AccessDeniedException("Token requerido");
        }
        try {
                IdentityPrincipal token = jwt.parse(authorization.substring(7));
                IdentityPrincipal principal = principals.load(token.userId(), token.tenantId())
                    .orElseThrow(() -> new AccessDeniedException("Cuenta inactiva o tenant no disponible"));
            var authorities = Stream.concat(
                    principal.roles().stream().map(role -> "ROLE_" + role),
                    principal.permissions().stream()
            ).map(SimpleGrantedAuthority::new).toList();
            accessor.setUser(new UsernamePasswordAuthenticationToken(principal, null, authorities));
        } catch (Exception exception) {
            throw new AccessDeniedException("Token inválido", exception);
        }
    }

    void authorizeSubscription(StompHeaderAccessor accessor) {
        IdentityPrincipal authenticated = principal(accessor);
        String destination = accessor.getDestination();
        if (authenticated == null || destination == null) {
            throw new AccessDeniedException("Suscripción no autorizada");
        }
        IdentityPrincipal principal = principals.load(authenticated.userId(), authenticated.tenantId())
            .orElseThrow(() -> new AccessDeniedException("Cuenta inactiva o tenant no disponible"));
        var authorities = Stream.concat(principal.roles().stream().map(role -> "ROLE_" + role),
            principal.permissions().stream()).map(SimpleGrantedAuthority::new).toList();
        accessor.setUser(new UsernamePasswordAuthenticationToken(principal, null, authorities));
        String customerPrefix = "/user/queue/orders/";
        if (destination.startsWith(customerPrefix)) {
            authorizeCustomerTracking(principal, destination, customerPrefix);
            return;
        }
        String prefix = "/topic/tenants/" + principal.tenantId() + "/";
        if (!destination.startsWith(prefix)) throw new AccessDeniedException("Tenant no autorizado");

                String audience = destination.substring(prefix.length());
                if (audience.startsWith("deliveries/")) {
                        UUID delivery = parseChannelId(audience.substring("deliveries/".length()));
                        boolean admin = hasDeliveryAdmin(principal);
                        int allowed = db.sql("""
                                        select count(*) from deliveries d
                                        where d.id=:delivery and d.tenant_id=:tenant
                                            and (d.customer_id=:user or d.courier_id in(
                                                select id from courier_profiles where tenant_id=:tenant and user_id=:user
                                            ) or :admin)
                                        """).param("delivery", delivery).param("tenant", principal.tenantId())
                                        .param("user", principal.userId()).param("admin", admin)
                                        .query(Integer.class).single();
                        if (allowed == 0) throw new AccessDeniedException("Entrega no autorizada");
                        return;
                }
                if (audience.startsWith("merchant/")) {
                        UUID merchant = parseChannelId(audience.substring("merchant/".length()));
                        boolean tenantAdmin = principal.roles().contains("TENANT_ADMIN")
                                        || principal.roles().contains("PLATFORM_ADMIN");
                        int allowed = db.sql("""
                                        select count(*) from merchants m
                                        where m.id=:merchant and m.tenant_id=:tenant and (
                                            :admin or exists(select 1 from merchant_memberships mm
                                                where mm.tenant_id=m.tenant_id and mm.merchant_id=m.id and m.status='ACTIVE'
                                                    and mm.user_id=:user and mm.active
                                                    and not exists(select 1 from branches b where b.tenant_id=m.tenant_id
                                                        and b.merchant_id=m.id and not exists(select 1 from merchant_branch_assignments mba
                                                            where mba.membership_id=mm.id and mba.branch_id=b.id)))
                                        )
                                        """).param("merchant", merchant).param("tenant", principal.tenantId())
                                        .param("user", principal.userId()).param("admin", tenantAdmin)
                                        .query(Integer.class).single();
                        if (allowed == 0) throw new AccessDeniedException("Comercio no autorizado");
                        return;
                }
                if (audience.startsWith("courier/")) {
                        UUID user = parseChannelId(audience.substring("courier/".length()));
                        if (!user.equals(principal.userId()) && !hasDeliveryAdmin(principal))
                                throw new AccessDeniedException("Canal de repartidor no autorizado");
                        return;
                }
                if ("admin".equals(audience)) {
                        if (!hasDeliveryAdmin(principal)) throw new AccessDeniedException("Canal administrativo no autorizado");
                        return;
                }
                if ("courier".equals(audience)) {
                        if (!principal.permissions().contains("COURIER_VIEW") && !hasDeliveryAdmin(principal))
                                throw new AccessDeniedException("Flota no autorizada");
                        return;
                }
                if ("customers".equals(audience)) {
                        if (!principal.roles().contains("CUSTOMER"))
                                throw new AccessDeniedException("Canal exclusivo para clientes");
                        return;
                }
                throw new AccessDeniedException("Canal no autorizado");
    }

    private void authorizeCustomerTracking(IdentityPrincipal principal, String destination, String prefix) {
        if (!principal.roles().contains("CUSTOMER")) {
            throw new AccessDeniedException("Canal exclusivo para clientes");
        }
        String suffix = destination.substring(prefix.length());
        if (!suffix.endsWith("/tracking")) throw new AccessDeniedException("Canal inválido");
        UUID orderId;
        try {
            orderId = UUID.fromString(suffix.substring(0, suffix.length() - "/tracking".length()));
        } catch (Exception exception) {
            throw new AccessDeniedException("Canal inválido");
        }
        int allowed = db.sql("""
                select count(*) from orders o
                where o.id=:order and o.tenant_id=:tenant and o.customer_id=:user
                """).param("order", orderId).param("tenant", principal.tenantId())
                .param("user", principal.userId()).query(Integer.class).single();
        if (allowed == 0) throw new AccessDeniedException("Pedido no autorizado");
    }

    private IdentityPrincipal principal(StompHeaderAccessor accessor) {
        if (accessor.getUser() instanceof Authentication authentication
                && authentication.getPrincipal() instanceof IdentityPrincipal principal) return principal;
        return null;
    }

    private UUID parseChannelId(String value) {
        try {
            return UUID.fromString(value);
        } catch (Exception exception) {
            throw new AccessDeniedException("Canal inválido");
        }
    }

    private boolean hasDeliveryAdmin(IdentityPrincipal principal) {
        return principal.permissions().contains("TRACKING_ADMIN")
                || principal.permissions().contains("DELIVERY_ADMIN");
    }
}
