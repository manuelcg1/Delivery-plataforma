package com.delivery.platform.tracking.api;

import com.delivery.platform.identity.security.IdentityPrincipal;
import com.delivery.platform.tracking.application.CourierInteractionService;
import com.delivery.platform.tracking.application.CourierInteractionService.*;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1")
public class CourierInteractionController {
    public record CodeRequest(@NotBlank String value) {}
    public record ChatRequest(UUID deliveryId, @NotBlank String channel, @NotBlank @Size(max = 1000) String message) {}

    private final CourierInteractionService service;

    public CourierInteractionController(CourierInteractionService service) {
        this.service = service;
    }

    @PostMapping(value = "/orders/{id}/proof", consumes = "multipart/form-data")
    @PreAuthorize("hasAuthority('PROOF_CREATE')")
    @ResponseStatus(HttpStatus.CREATED)
    Proof proof(@AuthenticationPrincipal IdentityPrincipal principal, @PathVariable UUID id,
                @RequestParam String type, @RequestParam(required = false) String comments,
                @RequestPart("file") MultipartFile file) {
        return service.upload(principal, id, type, comments, file);
    }

    @GetMapping("/orders/{id}/proof")
    @PreAuthorize("hasAuthority('PROOF_VIEW')")
    List<Proof> proofs(@AuthenticationPrincipal IdentityPrincipal principal, @PathVariable UUID id) {
        return service.proofs(principal, id);
    }

    @PostMapping("/orders/{id}/otp")
    @PreAuthorize("hasAuthority('PROOF_CREATE')")
    TemporaryCode otp(@AuthenticationPrincipal IdentityPrincipal principal, @PathVariable UUID id) {
        return service.createOtp(principal, id);
    }

    @PostMapping("/orders/{id}/otp/validate")
    @PreAuthorize("hasAuthority('PROOF_CREATE')")
    Map<String, String> validateOtp(@AuthenticationPrincipal IdentityPrincipal principal, @PathVariable UUID id,
                                    @Valid @RequestBody CodeRequest request) {
        service.validateOtp(principal, id, request.value());
        return Map.of("status", "validated");
    }

    @PostMapping("/orders/{id}/qr")
    @PreAuthorize("hasAuthority('PROOF_CREATE')")
    TemporaryCode qr(@AuthenticationPrincipal IdentityPrincipal principal, @PathVariable UUID id) {
        return service.createQr(principal, id);
    }

    @PostMapping("/orders/{id}/qr/scan")
    @PreAuthorize("hasAuthority('PROOF_CREATE')")
    Map<String, String> scanQr(@AuthenticationPrincipal IdentityPrincipal principal, @PathVariable UUID id,
                               @Valid @RequestBody CodeRequest request) {
        service.scanQr(principal, id, request.value());
        return Map.of("status", "scanned");
    }

    @PostMapping("/chat/messages")
    @PreAuthorize("hasAuthority('CHAT_SEND')")
    @ResponseStatus(HttpStatus.CREATED)
    Message message(@AuthenticationPrincipal IdentityPrincipal principal, @Valid @RequestBody ChatRequest request) {
        return service.message(principal, request.deliveryId(), request.channel(), request.message());
    }

    @GetMapping("/chat/history")
    @PreAuthorize("hasAuthority('CHAT_VIEW')")
    List<Message> history(@AuthenticationPrincipal IdentityPrincipal principal, @RequestParam UUID deliveryId,
                          @RequestParam(required = false) String channel) {
        return service.history(principal, deliveryId, channel);
    }

    @GetMapping("/notifications")
    @PreAuthorize("hasAuthority('NOTIFICATION_VIEW')")
    List<Notification> notifications(@AuthenticationPrincipal IdentityPrincipal principal) {
        return service.notifications(principal);
    }
}
