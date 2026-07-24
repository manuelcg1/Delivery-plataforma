package com.delivery.platform.tracking.application;

import com.delivery.platform.tracking.application.TrackingService.Location;
import com.delivery.platform.tracking.application.TrackingService.LocationCommand;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;

class TrackingServiceTest {
    private final TrackingService service = new TrackingService(
            mock(org.springframework.jdbc.core.simple.JdbcClient.class),
            mock(org.springframework.data.redis.core.StringRedisTemplate.class),
            mock(com.delivery.platform.tracking.realtime.RealtimeGateway.class),
            BigDecimal.valueOf(100), BigDecimal.valueOf(180));

    @Test
    void calculatesDistanceWithProviderIndependentHaversine() {
        double distance = TrackingService.haversine(
                new BigDecimal("-12.0464"), new BigDecimal("-77.0428"),
                new BigDecimal("-12.1191"), new BigDecimal("-77.0347"));
        assertThat(distance).isBetween(8.0, 8.3);
    }

    @Test
    void rejectsImpossibleGpsJump() {
        Instant initial = Instant.parse("2026-07-18T20:00:00Z");
        Location previous = new Location(UUID.randomUUID(), UUID.randomUUID(), null,
                new BigDecimal("-12.0464"), new BigDecimal("-77.0428"), null, null,
                BigDecimal.TEN, null, "gps", 80, initial, initial);
        LocationCommand next = new LocationCommand(new BigDecimal("-13.5319"), new BigDecimal("-71.9675"),
                null, null, BigDecimal.TEN, null, "gps", 80, initial.plusSeconds(5));
        assertThat(service.impossible(previous, next)).isTrue();
    }

    @Test
    void acceptsPlausibleGpsMovement() {
        Instant initial = Instant.parse("2026-07-18T20:00:00Z");
        Location previous = new Location(UUID.randomUUID(), UUID.randomUUID(), null,
                new BigDecimal("-12.046400"), new BigDecimal("-77.042800"), null, null,
                BigDecimal.TEN, null, "gps", 80, initial, initial);
        LocationCommand next = new LocationCommand(new BigDecimal("-12.046500"), new BigDecimal("-77.042900"),
                null, null, BigDecimal.TEN, null, "gps", 80, initial.plusSeconds(5));
        assertThat(service.impossible(previous, next)).isFalse();
    }
}
