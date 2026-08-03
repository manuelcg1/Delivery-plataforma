package com.delivery.platform.delivery.application;

import static org.assertj.core.api.Assertions.assertThat;

import java.math.BigDecimal;
import org.junit.jupiter.api.Test;

class DeliveryCoverageCalculationTest {
    @Test
    void trujilloAddressInsideThreeKilometerRadiusIsCovered() {
        BigDecimal distance = DeliveryCoverageService.distanceKm(
                new BigDecimal("-8.1116"), new BigDecimal("-79.0288"),
                new BigDecimal("-8.1250"), new BigDecimal("-79.0380"));

        assertThat(distance).isEqualByComparingTo("1.80");
        assertThat(distance).isLessThanOrEqualTo(new BigDecimal("3.00"));
    }

    @Test
    void limaAddressIsOutsideTrujilloRadius() {
        BigDecimal distance = DeliveryCoverageService.distanceKm(
                new BigDecimal("-8.1116"), new BigDecimal("-79.0288"),
                new BigDecimal("-12.0464"), new BigDecimal("-77.0428"));

        assertThat(distance).isGreaterThan(new BigDecimal("400"));
    }

    @Test
    void rejectsMissingAndInvalidBranchCoordinates() {
        assertThat(DeliveryCoverageService.configurationError(null, null, true, new BigDecimal("3")))
                .isEqualTo("BRANCH_LOCATION_MISSING");
        assertThat(DeliveryCoverageService.configurationError(new BigDecimal("91"), BigDecimal.ZERO, true, new BigDecimal("3")))
                .isEqualTo("BRANCH_LOCATION_MISSING");
    }

    @Test
    void rejectsDisabledMissingZeroAndNegativeCoverageRadius() {
        BigDecimal latitude = new BigDecimal("-8.1116");
        BigDecimal longitude = new BigDecimal("-79.0288");
        assertThat(DeliveryCoverageService.configurationError(latitude, longitude, false, new BigDecimal("3")))
                .isEqualTo("COVERAGE_NOT_CONFIGURED");
        assertThat(DeliveryCoverageService.configurationError(latitude, longitude, true, null))
                .isEqualTo("COVERAGE_NOT_CONFIGURED");
        assertThat(DeliveryCoverageService.configurationError(latitude, longitude, true, BigDecimal.ZERO))
                .isEqualTo("COVERAGE_NOT_CONFIGURED");
        assertThat(DeliveryCoverageService.configurationError(latitude, longitude, true, new BigDecimal("-1")))
                .isEqualTo("COVERAGE_NOT_CONFIGURED");
    }
}
