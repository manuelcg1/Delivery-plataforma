package com.delivery.platform.catalog.merchant.api;

import com.delivery.platform.catalog.media.application.MerchantMediaService;
import com.delivery.platform.catalog.media.application.MerchantMediaService.MerchantImage;
import com.delivery.platform.catalog.media.application.MerchantMediaService.Type;
import com.delivery.platform.identity.security.IdentityPrincipal;
import java.util.UUID;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/v1/merchants/{merchantId}")
public class MerchantMediaController {
    private final MerchantMediaService service;

    public MerchantMediaController(MerchantMediaService service) {
        this.service = service;
    }

    @PostMapping(value = "/logo", consumes = "multipart/form-data")
    @PreAuthorize("hasAuthority('CATALOG_MEDIA_UPLOAD')")
    MerchantImage logo(@AuthenticationPrincipal IdentityPrincipal principal, @PathVariable UUID merchantId,
                       @RequestPart("file") MultipartFile file) {
        return service.upload(principal, merchantId, Type.LOGO, file);
    }

    @PostMapping(value = "/banner", consumes = "multipart/form-data")
    @PreAuthorize("hasAuthority('CATALOG_MEDIA_UPLOAD')")
    MerchantImage banner(@AuthenticationPrincipal IdentityPrincipal principal, @PathVariable UUID merchantId,
                         @RequestPart("file") MultipartFile file) {
        return service.upload(principal, merchantId, Type.BANNER, file);
    }
}
