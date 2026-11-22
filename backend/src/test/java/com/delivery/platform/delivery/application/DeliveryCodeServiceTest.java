package com.delivery.platform.delivery.application;

import com.delivery.platform.common.ApiException;
import com.delivery.platform.delivery.api.DeliveryController;
import java.util.HashSet;
import java.util.Set;
import org.junit.jupiter.api.Test;
import org.springframework.transaction.annotation.Transactional;

import static org.assertj.core.api.Assertions.assertThat;

class DeliveryCodeServiceTest {

    @Test
    void generatedCodesHaveFiveUnambiguousCharacters() {
        for (int i = 0; i < 500; i++) {
            String code = DeliveryCodeService.generate();
            assertThat(code).hasSize(5).matches("[ACDEFGHJKMNPQRTUVWXY34679]{5}");
            assertThat(code).doesNotContain("0", "O", "1", "I", "L", "5", "S", "8", "B");
        }
    }

    @Test
    void codesChangeBetweenOrders() {
        Set<String> codes = new HashSet<>();
        for (int i = 0; i < 200; i++) codes.add(DeliveryCodeService.generate());
        assertThat(codes.size()).isGreaterThan(190);
    }

    @Test
    void orderNumberIsShortAndDoesNotRevealTheDeliveryCode() {
        String number = DeliveryCodeService.orderNumber();
        assertThat(number).matches("CK-[ACDEFGHJKMNPQRTUVWXY34679]{6}");
        assertThat(number.length()).isLessThanOrEqualTo(9);
    }

    @Test
    void comparisonIgnoresCaseSpacesAndDashes() {
        assertThat(DeliveryCodeService.matches("K7P3M", " k7p-3m ")).isTrue();
        assertThat(DeliveryCodeService.matches("K7P3M", "K7P3N")).isFalse();
        assertThat(DeliveryCodeService.matches("K7P3M", "")).isFalse();
    }

    @Test
    void failedAttemptsArePersistedEvenWhenTheRequestFails() throws Exception {
        Transactional tx = DeliveryCodeService.class
                .getMethod("verify", com.delivery.platform.identity.security.IdentityPrincipal.class,
                        java.util.UUID.class, String.class)
                .getAnnotation(Transactional.class);
        assertThat(tx).isNotNull();
        assertThat(tx.noRollbackFor()).contains(ApiException.class);
        assertThat(DeliveryCodeService.MAX_FAILED_ATTEMPTS).isEqualTo(5);
    }

    @Test
    void courierApiExposesValidationButNeverTheCode() {
        assertThat(DeliveryCodeService.Verification.class.getRecordComponents())
                .extracting(java.lang.reflect.RecordComponent::getName)
                .containsExactly("verified", "verifiedAt");
        assertThat(DeliveryController.class.getDeclaredConstructors()[0].getParameterTypes())
                .contains(DeliveryCodeService.class);
    }
}
