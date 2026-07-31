package com.delivery.platform.tracking.realtime;

import com.delivery.platform.identity.security.IdentityPrincipal;
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

    public WebSocketConfig(@Value("${CORS_ALLOWED_ORIGINS:http://localhost:3000}") String origins,
                           JdbcClient db, JwtService jwt) {
        this.origins = java.util.Arrays.stream(origins.split(",")).map(String::trim).toArray(String[]::new);
        this.db = db;
        this.jwt = jwt;
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
                if (accessor.getMessageType() == SimpMessageType.CONNECT) authenticate(accessor);
                if (accessor.getMessageType() != SimpMessageType.SUBSCRIBE) return message;
                authorizeSubscription(accessor);
                return message;
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
            IdentityPrincipal principal = jwt.parse(authorization.substring(7));
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
        IdentityPrincipal principal = principal(accessor);
        String destination = accessor.getDestination();
        if (principal == null || destination == null) {
            throw new AccessDeniedException("Suscripción no autorizada");
        }
        String customerPrefix = "/user/queue/orders/";
        if (destination.startsWith(customerPrefix)) {
            authorizeCustomerTracking(principal, destination, customerPrefix);
            return;
        }
        String prefix = "/topic/tenants/" + principal.tenantId() + "/";
        if (!destination.startsWith(prefix)) throw new AccessDeniedException("Tenant no autorizado");

        String marker = "/deliveries/";
        int position = destination.indexOf(marker);
        if (position < 0) return;
        UUID delivery;
        try {
            delivery = UUID.fromString(destination.substring(position + marker.length()));
        } catch (Exception exception) {
            throw new AccessDeniedException("Canal inválido");
        }
        boolean admin = principal.permissions().contains("TRACKING_ADMIN")
                || principal.permissions().contains("DELIVERY_ADMIN");
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
}
