package com.delivery.platform.delivery.application;

import com.delivery.platform.delivery.api.DeliveryController;
import com.delivery.platform.merchant.application.MerchantCourierAssignmentService;
import org.junit.jupiter.api.Test;

import java.util.Arrays;

import static org.assertj.core.api.Assertions.assertThat;

class AssignmentFlowArchitectureTest {
    @Test
    void deliveryServiceNoLongerOwnsAnAssignmentEntryPoint() {
        assertThat(Arrays.stream(DeliveryService.class.getDeclaredMethods())
                .map(java.lang.reflect.Method::getName))
                .doesNotContain("assign");
    }

    @Test
    void legacyRestContractDelegatesToTheUnifiedAssignmentService() {
        assertThat(Arrays.stream(DeliveryController.class.getDeclaredConstructors())
                .flatMap(constructor -> Arrays.stream(constructor.getParameterTypes())))
                .contains(MerchantCourierAssignmentService.class);
        assertThat(Arrays.stream(MerchantCourierAssignmentService.class.getDeclaredMethods())
                .map(java.lang.reflect.Method::getName))
                .contains("assignDelivery", "manualAssign", "autoAssign");
    }
}
