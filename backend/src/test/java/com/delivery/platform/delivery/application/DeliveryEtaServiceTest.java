package com.delivery.platform.delivery.application;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.math.BigDecimal;
import org.junit.jupiter.api.Test;

class DeliveryEtaServiceTest {
    private final DeliveryEtaService service =
            new DeliveryEtaService(5, 10, new BigDecimal("25"), 5);

    @Test
    void estimatesCompleteJourneyAndRange() {
        var eta = service.quote(20, new BigDecimal("5.00"));
        assertThat(eta.preparationMinutes()).isEqualTo(20);
        assertThat(eta.assignmentMinutes()).isEqualTo(5);
        assertThat(eta.courierToMerchantMinutes()).isEqualTo(10);
        assertThat(eta.merchantToCustomerMinutes()).isEqualTo(12);
        assertThat(eta.estimatedMinutes()).isEqualTo(47);
        assertThat(eta.minimumMinutes()).isEqualTo(42);
        assertThat(eta.maximumMinutes()).isEqualTo(52);
    }

    @Test
    void recalculatesRemainingJourneyFromGpsDistance() {
        assertThat(service.remainingMinutes(new BigDecimal("3.10"))).isEqualTo(8);
        assertThat(service.remainingMinutes(BigDecimal.ZERO)).isEqualTo(1);
    }

    @Test
    void rejectsUnsafeConfiguration() {
        assertThatThrownBy(() -> new DeliveryEtaService(5, 10, BigDecimal.ZERO, 5))
                .isInstanceOf(IllegalArgumentException.class);
    }
}
