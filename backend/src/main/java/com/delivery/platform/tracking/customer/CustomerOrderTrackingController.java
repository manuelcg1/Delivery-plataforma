package com.delivery.platform.tracking.customer;

import com.delivery.platform.common.ApiException;
import com.delivery.platform.identity.security.IdentityPrincipal;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/customer/orders")
public class CustomerOrderTrackingController {
    private final CustomerOrderTrackingService service;

    public CustomerOrderTrackingController(CustomerOrderTrackingService service) {
        this.service = service;
    }

    @GetMapping("/{orderId}/tracking")
    @PreAuthorize("hasRole('CUSTOMER')")
    CustomerOrderTrackingResponse tracking(@AuthenticationPrincipal IdentityPrincipal principal,
                                           @PathVariable String orderId) {
        try {
            return service.getTracking(UUID.fromString(orderId), principal);
        } catch (IllegalArgumentException exception) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "ORDER_ID_INVALID", "El identificador del pedido no es válido");
        }
    }
}
