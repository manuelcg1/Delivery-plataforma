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
    void manualYapeModeRejectsAllSimulatedMethodsBeforePersistence() {
        var db=mock(JdbcClient.class);
        var service=new PaymentService(db,List.of(new SimulatedPaymentProvider()),"MANUAL_YAPE");
        var principal=new IdentityPrincipal(UUID.randomUUID(),UUID.randomUUID(),"tenant",Set.of(),Set.of());
        for(var method:List.of(Method.CARD,Method.DIGITAL_WALLET,Method.BANK_TRANSFER,Method.OTHER)) {
            assertThatThrownBy(()->service.create(principal,UUID.randomUUID(),method,"token","key"))
                .isInstanceOf(ApiException.class).hasMessageContaining("pagos electrónicos");
        }
        org.mockito.Mockito.verifyNoInteractions(db);
    }
    @Test
    void unknownProviderFailsClosedBeforePersistence() {
        var db=mock(JdbcClient.class);
        var service=new PaymentService(db,List.of(new SimulatedPaymentProvider()),"UNKNOWN");
        var principal=new IdentityPrincipal(UUID.randomUUID(),UUID.randomUUID(),"tenant",Set.of(),Set.of());
        assertThatThrownBy(()->service.create(principal,UUID.randomUUID(),Method.CARD,"token","key"))
            .isInstanceOf(ApiException.class).hasMessageContaining("pagos electrónicos");
        org.mockito.Mockito.verifyNoInteractions(db);
    }
    @Test
    void cashOnlyModeRejectsElectronicPaymentsBeforePersistingAnything() {
        var service = new PaymentService(mock(JdbcClient.class), List.of(new SimulatedPaymentProvider()), "CASH_ONLY");
        var principal = new IdentityPrincipal(UUID.randomUUID(), UUID.randomUUID(), "tenant", Set.of(), Set.of());

        assertThatThrownBy(() -> service.create(principal, UUID.randomUUID(), Method.CARD, "token", "key"))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("pagos electrónicos");
    }
}
