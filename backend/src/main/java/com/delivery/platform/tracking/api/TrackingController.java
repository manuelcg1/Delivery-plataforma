package com.delivery.platform.tracking.api;

import com.delivery.platform.identity.security.IdentityPrincipal;
import com.delivery.platform.tracking.application.TrackingService;
import com.delivery.platform.tracking.application.TrackingService.*;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1")
public class TrackingController {
    public record LocationRequest(@NotNull @DecimalMin("-90") @DecimalMax("90") BigDecimal latitude,
                                  @NotNull @DecimalMin("-180") @DecimalMax("180") BigDecimal longitude,
                                  @PositiveOrZero BigDecimal speed, @DecimalMin("0") @DecimalMax("360") BigDecimal heading,
                                  @NotNull @PositiveOrZero BigDecimal accuracy, BigDecimal altitude,
                                  @Size(max = 30) String provider, @Min(0) @Max(100) Integer batteryLevel,
                                  @NotNull Instant gpsTimestamp) {}
    public record StatusRequest(@NotBlank String status) {}

    private final TrackingService service;

    public TrackingController(TrackingService service) {
        this.service = service;
    }

    @GetMapping("/couriers/me")
    @PreAuthorize("hasAuthority('COURIER_VIEW')")
    CourierMe me(@AuthenticationPrincipal IdentityPrincipal principal) {
        return service.me(principal);
    }

    @PutMapping("/couriers/status")
    @PreAuthorize("hasAuthority('COURIER_AVAILABILITY_MANAGE')")
    CourierMe status(@AuthenticationPrincipal IdentityPrincipal principal, @Valid @RequestBody StatusRequest request) {
        return service.status(principal, request.status());
    }

    @PostMapping("/couriers/location")
    @PreAuthorize("hasAnyAuthority('COURIER_LOCATION_UPDATE','COURIER_AVAILABILITY_MANAGE')")
    @ResponseStatus(HttpStatus.ACCEPTED)
    Optional<Location> location(@AuthenticationPrincipal IdentityPrincipal principal,
                                @Valid @RequestBody LocationRequest request) {
        return service.location(principal, new LocationCommand(request.latitude(), request.longitude(), request.speed(),
                request.heading(), request.accuracy(), request.altitude(), request.provider(), request.batteryLevel(), request.gpsTimestamp()));
    }

    @GetMapping("/orders/{id}/tracking")
    @PreAuthorize("hasAnyAuthority('TRACKING_VIEW','ORDERS_VIEW')")
    Tracking tracking(@AuthenticationPrincipal IdentityPrincipal principal, @PathVariable UUID id) {
        return service.tracking(principal, id);
    }

    @GetMapping("/tracking/couriers")
    @PreAuthorize("hasAuthority('TRACKING_VIEW')")
    List<Location> couriers(@AuthenticationPrincipal IdentityPrincipal principal) {
        return service.couriers(principal);
    }

    @GetMapping("/tracking/couriers/{id}/history")
    @PreAuthorize("hasAuthority('TRACKING_VIEW')")
    List<Location> history(@AuthenticationPrincipal IdentityPrincipal principal, @PathVariable UUID id,
                           @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant from,
                           @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant to) {
        return service.history(principal, id, from, to);
    }
}
