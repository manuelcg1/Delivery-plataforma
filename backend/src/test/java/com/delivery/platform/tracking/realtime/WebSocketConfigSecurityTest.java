package com.delivery.platform.tracking.realtime;

import com.delivery.platform.identity.security.IdentityPrincipal;
import com.delivery.platform.identity.security.IdentityPrincipalLoader;
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
    @Test void clientsCannotPublishToBrokerDestinations() {
        var registration=mock(org.springframework.messaging.simp.config.ChannelRegistration.class);
        config.configureClientInboundChannel(registration);
        var interceptor=org.mockito.ArgumentCaptor.forClass(org.springframework.messaging.support.ChannelInterceptor.class);
        verify(registration).interceptors(interceptor.capture());
        var header=StompHeaderAccessor.create(StompCommand.SEND);
        header.setDestination("/topic/tenants/"+tenant+"/merchant/"+UUID.randomUUID());
        var message=org.springframework.messaging.support.MessageBuilder.createMessage(new byte[0],header.getMessageHeaders());
        assertThatThrownBy(()->interceptor.getValue().preSend(message,mock(org.springframework.messaging.MessageChannel.class)))
                .isInstanceOf(AccessDeniedException.class);
    }
    @Test void outboundMerchantMessagesRecheckRevokedIdentity() {
        var inbound=mock(org.springframework.messaging.simp.config.ChannelRegistration.class);
        config.configureClientInboundChannel(inbound);
        var input=org.mockito.ArgumentCaptor.forClass(org.springframework.messaging.support.ChannelInterceptor.class);
        verify(inbound).interceptors(input.capture());
        var identity=new IdentityPrincipal(customer,tenant,"test",Set.of("MERCHANT_PORTAL_OPERATOR"),Set.of("MERCHANT_PORTAL_ACCESS"));
        var connect=StompHeaderAccessor.create(StompCommand.CONNECT);
        connect.setSessionId("merchant-session");
        connect.setUser(new UsernamePasswordAuthenticationToken(identity,null,java.util.List.of()));
        input.getValue().preSend(org.springframework.messaging.support.MessageBuilder.createMessage(new byte[0],connect.getMessageHeaders()),mock(org.springframework.messaging.MessageChannel.class));
        when(principals.load(customer,tenant)).thenReturn(java.util.Optional.empty());
        var outbound=mock(org.springframework.messaging.simp.config.ChannelRegistration.class);
        config.configureClientOutboundChannel(outbound);
        var output=org.mockito.ArgumentCaptor.forClass(org.springframework.messaging.support.ChannelInterceptor.class);
        verify(outbound).interceptors(output.capture());
        var header=org.springframework.messaging.simp.SimpMessageHeaderAccessor.create(org.springframework.messaging.simp.SimpMessageType.MESSAGE);
        header.setSessionId("merchant-session");
        header.setDestination("/topic/tenants/"+tenant+"/merchant/"+UUID.randomUUID());
        var message=org.springframework.messaging.support.MessageBuilder.createMessage(new byte[0],header.getMessageHeaders());
        org.assertj.core.api.Assertions.assertThat(output.getValue().preSend(message,mock(org.springframework.messaging.MessageChannel.class))).isNull();
        when(principals.load(customer,tenant)).thenReturn(java.util.Optional.of(identity));
        var permission=db.sql(anyString()).param(eq("merchant"),any(UUID.class)).param("tenant",tenant)
                .param("user",customer).param("admin",false).query(Integer.class);
        when(permission.single()).thenReturn(1);
        org.assertj.core.api.Assertions.assertThat(output.getValue().preSend(message,mock(org.springframework.messaging.MessageChannel.class))).isSameAs(message);
        when(permission.single()).thenReturn(0);
        org.assertj.core.api.Assertions.assertThat(output.getValue().preSend(message,mock(org.springframework.messaging.MessageChannel.class))).isNull();
        when(permission.single()).thenReturn(1);
        config.disconnected(new org.springframework.web.socket.messaging.SessionDisconnectEvent(this,message,"merchant-session",org.springframework.web.socket.CloseStatus.NORMAL));
        org.assertj.core.api.Assertions.assertThat(output.getValue().preSend(message,mock(org.springframework.messaging.MessageChannel.class))).isNull();
    }
    private JdbcClient db;
    private JwtService jwt;
    private IdentityPrincipalLoader principals;
    private WebSocketConfig config;
    private UUID tenant, customer, order;

    @BeforeEach void setUp() {
        db = mock(JdbcClient.class, RETURNS_DEEP_STUBS);
        jwt = mock(JwtService.class);
        principals = mock(IdentityPrincipalLoader.class);
        config = new WebSocketConfig("http://localhost:3000", db, jwt, principals);
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

        @Test void customerCannotSubscribeToTenantWideMerchantEvents() {
        var accessor = subscription(customer, "CUSTOMER", order);
        accessor.setDestination("/topic/tenants/" + tenant + "/merchant/" + UUID.randomUUID());
        when(principals.load(customer, tenant)).thenReturn(java.util.Optional.of(
            new IdentityPrincipal(customer, tenant, "elite", Set.of("CUSTOMER"), Set.of())));
            when(db.sql(anyString()).param(eq("merchant"), any(UUID.class)).param(eq("tenant"), eq(tenant))
                .param(eq("user"), eq(customer)).param(eq("admin"), eq(false))
                .query(Integer.class).single()).thenReturn(0);

        assertThatThrownBy(() -> config.authorizeSubscription(accessor))
            .isInstanceOf(AccessDeniedException.class);
        }

        @Test void customerCanSubscribeToGenericRefreshAudience() {
        var accessor = subscription(customer, "CUSTOMER", order);
        accessor.setDestination("/topic/tenants/" + tenant + "/customers");
        when(principals.load(customer, tenant)).thenReturn(java.util.Optional.of(
            new IdentityPrincipal(customer, tenant, "elite", Set.of("CUSTOMER"), Set.of())));

        assertThatCode(() -> config.authorizeSubscription(accessor)).doesNotThrowAnyException();
        }

    private StompHeaderAccessor subscription(UUID user, String role, UUID orderId) {
        var principal = new IdentityPrincipal(user, tenant, "elite", Set.of(role), Set.of("TRACKING_VIEW"));
        when(principals.load(user, tenant)).thenReturn(java.util.Optional.of(principal));
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
