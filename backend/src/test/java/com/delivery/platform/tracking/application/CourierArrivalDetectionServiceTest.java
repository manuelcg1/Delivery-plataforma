package com.delivery.platform.tracking.application;

import org.junit.jupiter.api.Test;
import java.math.BigDecimal;
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
}
