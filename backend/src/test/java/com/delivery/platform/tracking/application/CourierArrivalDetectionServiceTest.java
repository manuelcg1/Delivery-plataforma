package com.delivery.platform.tracking.application;

import org.junit.jupiter.api.Test;
import java.math.BigDecimal;
import java.time.Instant;
import static org.assertj.core.api.Assertions.assertThat;

class CourierArrivalDetectionServiceTest {
    @Test void calculatesDistanceInMeters() {
        double distance=CourierArrivalDetectionService.meters(
            new BigDecimal("-12.0464000"),new BigDecimal("-77.0428000"),
            new BigDecimal("-12.0460000"),new BigDecimal("-77.0428000"));
        assertThat(distance).isBetween(44.0,45.0);
    }

    @Test void samePointHasZeroDistance() {
        BigDecimal lat=new BigDecimal("-12.0464"),lon=new BigDecimal("-77.0428");
        assertThat(CourierArrivalDetectionService.meters(lat,lon,lat,lon)).isZero();
    }

    @Test void requiresConsecutivePointsAndMinimumDwell() {
        Instant now=Instant.parse("2026-08-07T12:00:30Z");
        assertThat(CourierArrivalDetectionService.meetsConfirmation(3,3,now.minusSeconds(20),now,20)).isTrue();
        assertThat(CourierArrivalDetectionService.meetsConfirmation(2,3,now.minusSeconds(30),now,20)).isFalse();
        assertThat(CourierArrivalDetectionService.meetsConfirmation(3,3,now.minusSeconds(19),now,20)).isFalse();
    }
}
