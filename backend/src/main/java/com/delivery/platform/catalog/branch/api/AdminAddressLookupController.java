package com.delivery.platform.catalog.branch.api;

import com.delivery.platform.customer.address.AddressLookupService;
import com.delivery.platform.customer.address.GoogleAddressClient.AddressResult;
import com.delivery.platform.customer.address.GoogleAddressClient.Suggestion;
import com.delivery.platform.identity.security.IdentityPrincipal;
import jakarta.servlet.http.HttpServletRequest;
import java.math.BigDecimal;
import java.util.List;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/admin/locations")
@PreAuthorize("hasAnyAuthority('CATALOG_BRANCHES_CREATE','CATALOG_BRANCHES_UPDATE')")
public class AdminAddressLookupController {
    public record Suggestions(List<Suggestion> suggestions) {}

    private final AddressLookupService service;

    public AdminAddressLookupController(AddressLookupService service) {
        this.service = service;
    }

    @GetMapping("/search")
    Suggestions search(@AuthenticationPrincipal IdentityPrincipal principal,
                       HttpServletRequest request,
                       @RequestParam String query,
                       @RequestParam String sessionToken,
                       @RequestParam(required = false) BigDecimal latitude,
                       @RequestParam(required = false) BigDecimal longitude) {
        return new Suggestions(service.autocomplete(principal, request, query,
                sessionToken, latitude, longitude));
    }

    @GetMapping("/place/{placeId}")
    AddressResult place(@AuthenticationPrincipal IdentityPrincipal principal,
                        HttpServletRequest request,
                        @PathVariable String placeId,
                        @RequestParam String sessionToken) {
        return service.details(principal, request, placeId, sessionToken);
    }

    @GetMapping("/reverse")
    AddressResult reverse(@AuthenticationPrincipal IdentityPrincipal principal,
                          HttpServletRequest request,
                          @RequestParam BigDecimal latitude,
                          @RequestParam BigDecimal longitude) {
        return service.reverse(principal, request, latitude, longitude);
    }
}
