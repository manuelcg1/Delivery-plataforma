package com.delivery.platform.tracking.customer;

import com.delivery.platform.common.ApiException;
import com.delivery.platform.identity.security.IdentityPrincipal;
import com.delivery.platform.tracking.customer.CustomerOrderTrackingRepository.TrackingSnapshot;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.time.Clock;
import java.time.Duration;
import java.util.Set;
import java.util.UUID;

@Service
public class CustomerOrderTrackingService {
    static final Set<String> ACTIVE_STATUSES = Set.of("PICKED_UP", "IN_TRANSIT", "ARRIVED_AT_CUSTOMER");
    static final Set<String> PRE_TRACKING_STATUSES = Set.of(
            "PENDING", "SEARCHING_COURIER", "ASSIGNED", "ACCEPTED", "ARRIVED_AT_MERCHANT");

    private final CustomerOrderTrackingRepository repository;
    private final Clock clock;
    private final Duration staleThreshold;

    public CustomerOrderTrackingService(CustomerOrderTrackingRepository repository, Clock clock,
            @Value("${tracking.customer.stale-threshold:PT60S}") Duration staleThreshold) {
        this.repository = repository;
        this.clock = clock;
        this.staleThreshold = staleThreshold;
    }

    public CustomerOrderTrackingResponse getTracking(UUID orderId, IdentityPrincipal principal) {
        TrackingSnapshot row = repository.findOwned(principal.tenantId(), principal.userId(), orderId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND,
                        "ORDER_TRACKING_NOT_FOUND", "Seguimiento no encontrado"));
        boolean active = ACTIVE_STATUSES.contains(row.status());
        boolean exposeLocation = active || !PRE_TRACKING_STATUSES.contains(row.status());
        TrackingLocationResponse location = exposeLocation && row.gpsTimestamp() != null
                ? new TrackingLocationResponse(row.latitude(), row.longitude(), row.speed(), row.heading(),
                        row.accuracy(), row.altitude(), row.gpsTimestamp()) : null;
        boolean stale = location == null || Duration.between(location.gpsTimestamp(), clock.instant())
                .compareTo(staleThreshold) > 0;
        CourierTrackingSummary courier = row.courierId() == null ? null
                : new CourierTrackingSummary(row.courierId(), row.courierName());
        TrackingRouteResponse route = active && row.routePolyline() != null && !row.routePolyline().isBlank()
                ? new TrackingRouteResponse(row.routePolyline(), row.routeProvider(), row.routeGeneratedAt(),
                        row.originLatitude(), row.originLongitude(),
                        row.destinationLatitude(), row.destinationLongitude())
                : null;
        return new CustomerOrderTrackingResponse(row.orderId(), row.deliveryId(), row.status(), courier,
                location, route, location == null ? null : row.receivedAt(), active, stale);
    }
}
