package com.delivery.platform.merchant.application;

import com.delivery.platform.common.ApiException;
import com.delivery.platform.identity.security.IdentityPrincipal;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.simple.JdbcClient;

import java.sql.Timestamp;
import java.time.Instant;
import java.util.Set;
import java.util.UUID;

import com.delivery.platform.tracking.realtime.RealtimeGateway;
import static org.mockito.Mockito.mock;

import static org.junit.jupiter.api.Assertions.*;

class MerchantPortalServiceTest {
    @Test void rejectsPlatformOwnerFromMerchantPortal() {
        var service = new MerchantPortalService(mock(JdbcClient.class), mock(RealtimeGateway.class));
        var principal = new IdentityPrincipal(UUID.randomUUID(), UUID.randomUUID(), "platform",
            Set.of("ROLE_PLATFORM_OWNER"), Set.of("PLATFORM_MANAGE"));

        ApiException error = assertThrows(ApiException.class, () -> service.context(principal));
        assertEquals("PLATFORM_OWNER_PORTAL_FORBIDDEN", error.code);
    }
    @Test void acceptsOnlyOperationalOrderTransitions() {
        assertDoesNotThrow(() -> MerchantPortalService.validateTransition("PENDING", "CONFIRMED"));
        assertDoesNotThrow(() -> MerchantPortalService.validateTransition("PREPARING", "READY"));
        assertThrows(ApiException.class, () -> MerchantPortalService.validateTransition("PENDING", "READY"));
        assertThrows(ApiException.class, () -> MerchantPortalService.validateTransition("DELIVERED", "PREPARING"));
    }

    @Test void reportPeriodUsesJdbcTimestampAndClampsDays() {
        Instant now = Instant.parse("2026-07-21T12:00:00Z");

        assertEquals(Timestamp.from(now.minusSeconds(30L * 86_400L)), MerchantPortalService.reportSince(30, now));
        assertEquals(Timestamp.from(now.minusSeconds(86_400L)), MerchantPortalService.reportSince(0, now));
        assertEquals(Timestamp.from(now.minusSeconds(365L * 86_400L)), MerchantPortalService.reportSince(500, now));
    }
}
