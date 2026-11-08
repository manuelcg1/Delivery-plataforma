package com.delivery.platform.merchant.api;

import com.delivery.platform.identity.security.IdentityPrincipal;
import com.delivery.platform.merchant.application.MerchantAccessService;
import jakarta.validation.Valid;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import java.util.List;
import java.util.UUID;
import static com.delivery.platform.merchant.api.MerchantAccessDtos.*;

@RestController
@RequestMapping("/api/v1/merchants/{id}/portal-access")
public class MerchantAccessController {
    private final MerchantAccessService service;
    public MerchantAccessController(MerchantAccessService service) { this.service=service; }
    @GetMapping
    @PreAuthorize("hasAuthority('CATALOG_MERCHANTS_VIEW') and hasAuthority('IDENTITY_USERS_VIEW')")
    public List<Access> list(@AuthenticationPrincipal IdentityPrincipal actor, @PathVariable UUID id) {
        return service.list(actor,id);
    }
    @PutMapping("/{userId}")
    @PreAuthorize("hasAuthority('CATALOG_MERCHANTS_UPDATE') and hasAuthority('IDENTITY_USERS_UPDATE')")
    public Access update(@AuthenticationPrincipal IdentityPrincipal actor, @PathVariable UUID id,
                         @PathVariable UUID userId, @Valid @RequestBody Update request) {
        return service.update(actor,id,userId,request);
    }
}
