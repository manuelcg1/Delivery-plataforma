package com.delivery.platform.tracking.application;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class CourierChatPolicyTest {
    @Test
    void chatOpensOnlyOnceTheOrderIsOnTheWay() {
        assertThat(CourierInteractionService.CHAT_OPEN_STATUSES)
                .containsExactlyInAnyOrder("IN_TRANSIT", "ARRIVED_AT_CUSTOMER");
    }

    @Test
    void messagesExposeReadStateAndUnreadCountersExist() throws Exception {
        assertThat(java.util.Arrays.stream(CourierInteractionService.Message.class.getRecordComponents())
                .map(java.lang.reflect.RecordComponent::getName)).contains("readAt");
        assertThat(CourierInteractionService.class.getMethod("unread",
                com.delivery.platform.identity.security.IdentityPrincipal.class, java.util.UUID.class)).isNotNull();
        assertThat(CourierInteractionService.class.getMethod("markRead",
                com.delivery.platform.identity.security.IdentityPrincipal.class, java.util.UUID.class)
                .getAnnotation(org.springframework.transaction.annotation.Transactional.class)).isNotNull();
    }
}
