package com.delivery.platform.payments.api;

import com.delivery.platform.identity.security.IdentityPrincipal;
import com.delivery.platform.payments.application.MerchantYapeService;
import com.delivery.platform.payments.application.MerchantYapeService.Settings;
import java.util.UUID;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/v1")
public class MerchantYapeController {
    private final MerchantYapeService service;
    public MerchantYapeController(MerchantYapeService service){this.service=service;}
    @GetMapping("/merchants/{id}/payment-methods/yape")
    @PreAuthorize("hasAnyAuthority('CATALOG_MERCHANTS_VIEW','CATALOG_MERCHANTS_CREATE','CATALOG_MERCHANTS_UPDATE')")
    public Settings admin(@AuthenticationPrincipal IdentityPrincipal p,@PathVariable UUID id){return service.admin(p,id);}
    @GetMapping("/customer/checkout/merchants/{id}/yape")
    @PreAuthorize("hasRole('CUSTOMER')")
    public Settings checkout(@AuthenticationPrincipal IdentityPrincipal p,@PathVariable UUID id){return service.checkout(p,id);}
    @PutMapping(value="/merchants/{id}/payment-methods/yape",consumes="multipart/form-data")
    @PreAuthorize("hasAnyAuthority('CATALOG_MERCHANTS_CREATE','CATALOG_MERCHANTS_UPDATE') and (#qr == null or hasAuthority('CATALOG_MEDIA_UPLOAD'))")
    public Settings save(@AuthenticationPrincipal IdentityPrincipal p,@PathVariable UUID id,@RequestParam boolean enabled,
                         @RequestParam(required=false) String phone,@RequestParam(required=false) String holderName,
                         @RequestPart(required=false) MultipartFile qr){return service.save(p,id,enabled,phone,holderName,qr);}
}
