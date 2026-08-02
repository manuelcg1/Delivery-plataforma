package com.delivery.platform.delivery.application;

import com.delivery.platform.delivery.domain.DeliveryTypes.Type;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verifyNoInteractions;

class DeliveryServiceTest {

    @Test
    void pickupDoesNotRequireDeliveryCoverage() {
        DeliveryCoverageService coverage = mock(DeliveryCoverageService.class);
        DeliveryService service = new DeliveryService(null, coverage, null);

        DeliveryCoverageService.Quote quote = service.deliveryQuote(
                Type.PICKUP,
                UUID.randomUUID(),
                UUID.randomUUID(),
                UUID.randomUUID(),
                UUID.randomUUID(),
                UUID.randomUUID(),
                new BigDecimal("100.00"),
                "PEN"
        );

        assertThat(quote.eligible()).isTrue();
        assertThat(quote.deliveryFee()).isEqualByComparingTo(BigDecimal.ZERO);
        assertThat(quote.currency()).isEqualTo("PEN");
        verifyNoInteractions(coverage);
    }
}
