package com.delivery.platform.customer.address;

import com.delivery.platform.customer.address.GoogleAddressClient.*;
import com.delivery.platform.identity.security.IdentityPrincipal;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.constraints.*;
import java.math.BigDecimal;
import java.util.List;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;

@Validated @RestController @RequestMapping("/api/v1/customer") @PreAuthorize("hasRole('CUSTOMER')")
public class CustomerAddressLookupController {
    public record Suggestions(List<Suggestion> suggestions){}
    private final AddressLookupService service;public CustomerAddressLookupController(AddressLookupService service){this.service=service;}
    @GetMapping("/address-search") Suggestions search(@AuthenticationPrincipal IdentityPrincipal p,HttpServletRequest request,@RequestParam String query,@RequestParam String sessionToken,@RequestParam(required=false) BigDecimal latitude,@RequestParam(required=false) BigDecimal longitude){return new Suggestions(service.autocomplete(p,request,query,sessionToken,latitude,longitude));}
    @GetMapping("/address-place/{placeId}") AddressResult place(@AuthenticationPrincipal IdentityPrincipal p,HttpServletRequest request,@PathVariable String placeId,@RequestParam String sessionToken){return service.details(p,request,placeId,sessionToken);}
    @GetMapping("/address-reverse-geocode") AddressResult reverse(@AuthenticationPrincipal IdentityPrincipal p,HttpServletRequest request,@RequestParam BigDecimal latitude,@RequestParam BigDecimal longitude){return service.reverse(p,request,latitude,longitude);}
}
