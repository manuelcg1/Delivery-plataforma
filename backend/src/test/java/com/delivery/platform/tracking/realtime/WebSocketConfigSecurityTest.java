package com.delivery.platform.tracking.realtime;

import com.delivery.platform.identity.security.IdentityPrincipal;
import com.delivery.platform.identity.security.JwtService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.messaging.simp.stomp.StompCommand;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;

import java.util.List;
import java.util.Set;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.*;

class WebSocketConfigSecurityTest {
    private JdbcClient db;
    private JwtService jwt;
    private WebSocketConfig config;
    private UUID tenant, customer, order;

    @BeforeEach void setUp() {
        db = mock(JdbcClient.class, RETURNS_DEEP_STUBS);
        jwt = mock(JwtService.class);
        config = new WebSocketConfig("http://localhost:3000", db, jwt);
        tenant = UUID.randomUUID(); customer = UUID.randomUUID(); order = UUID.randomUUID();
    }

    @Test void ownerCanSubscribeToPrivateOrderQueue() {
        allowOrder(1);
        assertThatCode(() -> config.authorizeSubscription(subscription(customer, "CUSTOMER", order)))
                .doesNotThrowAnyException();
    }

    @Test void foreignCustomerCannotSubscribe() {
        allowOrder(0);
        assertThatThrownBy(() -> config.authorizeSubscription(subscription(customer, "CUSTOMER", order)))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test void unauthenticatedSubscriptionIsRejected() {
        var accessor = StompHeaderAccessor.create(StompCommand.SUBSCRIBE);
        accessor.setDestination(destination(order));
        assertThatThrownBy(() -> config.authorizeSubscription(accessor))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test void merchantAndCourierCannotUseCustomerQueue() {
        assertThatThrownBy(() -> config.authorizeSubscription(subscription(UUID.randomUUID(), "MERCHANT_OPERATOR", order)))
                .isInstanceOf(AccessDeniedException.class);
        assertThatThrownBy(() -> config.authorizeSubscription(subscription(UUID.randomUUID(), "COURIER", order)))
                .isInstanceOf(AccessDeniedException.class);
    }

    @Test void expiredOrInvalidConnectTokenIsRejected() {
        var accessor = StompHeaderAccessor.create(StompCommand.CONNECT);
        accessor.setNativeHeader("Authorization", "Bearer expired");
        when(jwt.parse("expired")).thenThrow(new IllegalArgumentException("expired"));
        assertThatThrownBy(() -> config.authenticate(accessor)).isInstanceOf(AccessDeniedException.class);
    }

    @Test void connectWithoutTokenIsRejected() {
        assertThatThrownBy(() -> config.authenticate(StompHeaderAccessor.create(StompCommand.CONNECT)))
                .isInstanceOf(AccessDeniedException.class);
    }

    private StompHeaderAccessor subscription(UUID user, String role, UUID orderId) {
        var principal = new IdentityPrincipal(user, tenant, "elite", Set.of(role), Set.of("TRACKING_VIEW"));
        var accessor = StompHeaderAccessor.create(StompCommand.SUBSCRIBE);
        accessor.setUser(new UsernamePasswordAuthenticationToken(principal, null, List.of()));
        accessor.setDestination(destination(orderId));
        return accessor;
    }

    private String destination(UUID orderId) { return "/user/queue/orders/" + orderId + "/tracking"; }

    private void allowOrder(int count) {
        when(db.sql(anyString()).param("order", order).param("tenant", tenant)
                .param("user", customer).query(Integer.class).single()).thenReturn(count);
    }
}
