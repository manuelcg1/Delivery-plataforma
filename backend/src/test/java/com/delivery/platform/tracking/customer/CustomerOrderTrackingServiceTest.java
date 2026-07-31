package com.delivery.platform.tracking.customer;

import com.delivery.platform.common.ApiException;
import com.delivery.platform.identity.security.IdentityPrincipal;
import com.delivery.platform.tracking.customer.CustomerOrderTrackingRepository.TrackingSnapshot;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.*;

class CustomerOrderTrackingServiceTest {
    private final UUID tenant = UUID.randomUUID(), customer = UUID.randomUUID(), order = UUID.randomUUID();
    private final Instant now = Instant.parse("2026-07-31T15:31:00Z");
    private CustomerOrderTrackingRepository repository;
    private CustomerOrderTrackingService service;
    private IdentityPrincipal principal;

    @BeforeEach
    void setUp() {
        repository = mock(CustomerOrderTrackingRepository.class);
        service = new CustomerOrderTrackingService(repository,
                Clock.fixed(now, ZoneOffset.UTC), Duration.ofSeconds(60));
        principal = new IdentityPrincipal(customer, tenant, "elite", Set.of("CUSTOMER"), Set.of("TRACKING_VIEW"));
    }

    @Test void activeOrderWithRecentLocationReturnsCustomerSafeTracking() {
        when(repository.findOwned(tenant, customer, order)).thenReturn(Optional.of(row("IN_TRANSIT", now.minusSeconds(20))));
        var response = service.getTracking(order, principal);
        assertThat(response.trackingActive()).isTrue();
        assertThat(response.stale()).isFalse();
        assertThat(response.location().latitude()).isEqualTo(-12.0464);
        assertThat(response.courier().displayName()).isEqualTo("Carlos M.");
    }

    @Test void activeOrderWithoutLocationDoesNotFail() {
        when(repository.findOwned(tenant, customer, order)).thenReturn(Optional.of(row("PICKED_UP", null)));
        var response = service.getTracking(order, principal);
        assertThat(response.trackingActive()).isTrue();
        assertThat(response.location()).isNull();
        assertThat(response.updatedAt()).isNull();
        assertThat(response.stale()).isTrue();
    }

    @Test void locationOlderThanThresholdIsStale() {
        when(repository.findOwned(tenant, customer, order)).thenReturn(Optional.of(row("IN_TRANSIT", now.minusSeconds(61))));
        assertThat(service.getTracking(order, principal).stale()).isTrue();
    }

    @Test void preTrackingStateHidesAnyPreviousLocation() {
        when(repository.findOwned(tenant, customer, order)).thenReturn(Optional.of(row("ACCEPTED", now.minusSeconds(5))));
        var response = service.getTracking(order, principal);
        assertThat(response.trackingActive()).isFalse();
        assertThat(response.location()).isNull();
    }

    @Test void deliveredOrderIsInactiveAndMayReturnFinalLocation() {
        when(repository.findOwned(tenant, customer, order)).thenReturn(Optional.of(row("DELIVERED", now.minusSeconds(5))));
        var response = service.getTracking(order, principal);
        assertThat(response.trackingActive()).isFalse();
        assertThat(response.location()).isNotNull();
    }

    @Test void cancelledOrderIsInactive() {
        when(repository.findOwned(tenant, customer, order)).thenReturn(Optional.of(row("CANCELLED", null)));
        assertThat(service.getTracking(order, principal).trackingActive()).isFalse();
    }

    @Test void nonexistentOrForeignOrderUsesSameNotFoundResponse() {
        when(repository.findOwned(tenant, customer, order)).thenReturn(Optional.empty());
        assertThatThrownBy(() -> service.getTracking(order, principal))
                .isInstanceOfSatisfying(ApiException.class, error -> {
                    assertThat(error.status.value()).isEqualTo(404);
                    assertThat(error.code).isEqualTo("ORDER_TRACKING_NOT_FOUND");
                });
    }

    @Test void deliveryWithoutCourierReturnsNullSummary() {
        TrackingSnapshot row = new TrackingSnapshot(order, UUID.randomUUID(), "PENDING", null, null,
                null, null, null, null, null, null, null, null);
        when(repository.findOwned(tenant, customer, order)).thenReturn(Optional.of(row));
        assertThat(service.getTracking(order, principal).courier()).isNull();
    }

    @Test void repositoryIsAlwaysScopedByAuthenticatedTenantAndCustomer() {
        when(repository.findOwned(tenant, customer, order)).thenReturn(Optional.of(row("PICKED_UP", null)));
        service.getTracking(order, principal);
        verify(repository).findOwned(tenant, customer, order);
    }

    private TrackingSnapshot row(String status, Instant gpsTimestamp) {
        boolean located = gpsTimestamp != null;
        return new TrackingSnapshot(order, UUID.randomUUID(), status, UUID.randomUUID(), "Carlos M.",
                located ? -12.0464 : null, located ? -77.0428 : null, located ? 25.0 : null,
                located ? 180.0 : null, located ? 8.0 : null, located ? 120.0 : null,
                gpsTimestamp, located ? gpsTimestamp.plusSeconds(1) : null);
    }
}
