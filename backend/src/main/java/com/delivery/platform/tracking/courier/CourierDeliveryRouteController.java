package com.delivery.platform.tracking.courier;

import com.delivery.platform.identity.security.IdentityPrincipal;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/courier/deliveries")
public class CourierDeliveryRouteController {
    private final CourierDeliveryRouteService service;

    public CourierDeliveryRouteController(CourierDeliveryRouteService service) {
        this.service = service;
    }

    @GetMapping("/{deliveryId}/route")
    @PreAuthorize("hasRole('COURIER') and hasAuthority('DELIVERY_VIEW')")
    CourierDeliveryRouteService.RouteView route(@PathVariable UUID deliveryId,
                                                 @AuthenticationPrincipal IdentityPrincipal principal) {
        return service.get(deliveryId, principal);
    }
}
