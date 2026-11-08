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
import static org.mockito.Mockito.*;

import static org.junit.jupiter.api.Assertions.*;

class MerchantPortalServiceTest {
    @Test void allowsPlatformOwnerInAValidatedOperationalTenantContext() {
        JdbcClient db = mock(JdbcClient.class, RETURNS_DEEP_STUBS);
        var service = new MerchantPortalService(db, mock(RealtimeGateway.class));
        UUID tenant = UUID.randomUUID();
        var principal = new IdentityPrincipal(UUID.randomUUID(), tenant, "north-shop",
            Set.of("ROLE_PLATFORM_OWNER", "TENANT_ADMIN"), Set.of("PLATFORM_MANAGE", "MERCHANT_PORTAL_ACCESS"));

        var context = service.context(principal);

        assertEquals(tenant, context.tenantId());
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
