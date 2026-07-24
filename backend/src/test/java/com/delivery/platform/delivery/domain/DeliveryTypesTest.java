package com.delivery.platform.delivery.domain;

import com.delivery.platform.common.ApiException;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class DeliveryTypesTest {
    @Test
    void permitsExpectedTransition() {
        assertThatCode(() -> DeliveryTypes.validate(
                DeliveryTypes.Status.ASSIGNED, DeliveryTypes.Status.ACCEPTED))
                .doesNotThrowAnyException();
    }

    @Test
    void permitsSimplifiedCourierTransitions() {
        assertThatCode(() -> DeliveryTypes.validate(
                DeliveryTypes.Status.ACCEPTED, DeliveryTypes.Status.PICKED_UP))
                .doesNotThrowAnyException();
        assertThatCode(() -> DeliveryTypes.validate(
                DeliveryTypes.Status.IN_TRANSIT, DeliveryTypes.Status.DELIVERED))
                .doesNotThrowAnyException();
    }

    @Test
    void rejectsArbitraryTransition() {
        assertThatThrownBy(() -> DeliveryTypes.validate(
                DeliveryTypes.Status.PENDING, DeliveryTypes.Status.DELIVERED))
                .isInstanceOf(ApiException.class);
    }
}
