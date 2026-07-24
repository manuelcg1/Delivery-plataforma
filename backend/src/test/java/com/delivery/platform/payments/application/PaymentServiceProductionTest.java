package com.delivery.platform.payments.application;

import com.delivery.platform.common.ApiException;
import com.delivery.platform.identity.security.IdentityPrincipal;
import com.delivery.platform.payments.domain.PaymentTypes.Method;
import com.delivery.platform.payments.infrastructure.SimulatedPaymentProvider;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.simple.JdbcClient;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;

class PaymentServiceProductionTest {
    @Test
    void cashOnlyModeRejectsElectronicPaymentsBeforePersistingAnything() {
        var service = new PaymentService(mock(JdbcClient.class), List.of(new SimulatedPaymentProvider()), "CASH_ONLY");
        var principal = new IdentityPrincipal(UUID.randomUUID(), UUID.randomUUID(), "tenant", Set.of(), Set.of());

        assertThatThrownBy(() -> service.create(principal, UUID.randomUUID(), Method.CARD, "token", "key"))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("pagos electrónicos");
    }
}
