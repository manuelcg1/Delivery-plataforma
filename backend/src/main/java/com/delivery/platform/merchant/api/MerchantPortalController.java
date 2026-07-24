package com.delivery.platform.merchant.api;

import com.delivery.platform.common.PageResponse;
import com.delivery.platform.identity.security.IdentityPrincipal;
import com.delivery.platform.merchant.application.MerchantPortalService;
import com.delivery.platform.merchant.application.MerchantCourierAssignmentService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/merchant")
public class MerchantPortalController {
    private final MerchantPortalService service;
    private final MerchantCourierAssignmentService couriers;
    public MerchantPortalController(MerchantPortalService service,MerchantCourierAssignmentService couriers) { this.service = service;this.couriers=couriers; }

    public record Transition(@NotBlank String status, @PositiveOrZero int expectedVersion, @Size(max=500) String reason) {}
    public record Pause(@Min(1) @Max(1440) Integer minutes, @Size(max=255) String reason) {}
    public record ManualAssignment(@NotNull UUID courierId) {}

    @GetMapping("/context")
    @PreAuthorize("hasAuthority('MERCHANT_PORTAL_ACCESS')")
    MerchantPortalService.Context context(@AuthenticationPrincipal IdentityPrincipal p) { return service.context(p); }

    @GetMapping("/orders")
    @PreAuthorize("hasAuthority('MERCHANT_ORDERS_VIEW')")
    PageResponse<MerchantPortalService.OrderRow> orders(@AuthenticationPrincipal IdentityPrincipal p,
        @RequestParam UUID merchantId, @RequestParam(required=false) UUID branchId,
        @RequestParam(required=false) String status, @RequestParam(required=false) String search,
        @RequestParam(defaultValue="0") int page, @RequestParam(defaultValue="25") int size) {
        return service.orders(p, merchantId, branchId, status, search, page, size);
    }

    @GetMapping("/orders/{id}")
    @PreAuthorize("hasAuthority('MERCHANT_ORDERS_VIEW')")
    MerchantPortalService.OrderDetail order(@AuthenticationPrincipal IdentityPrincipal p, @PathVariable UUID id) { return service.order(p, id); }

    @GetMapping("/orders/status-counts")
    @PreAuthorize("hasAnyAuthority('MERCHANT_ORDER_VIEW','MERCHANT_ORDERS_VIEW')")
    java.util.List<MerchantPortalService.StatusCount> counts(@AuthenticationPrincipal IdentityPrincipal p,@RequestParam UUID merchantId,@RequestParam(required=false)UUID branchId){return service.statusCounts(p,merchantId,branchId);}

    @GetMapping("/orders/{id}/delivery/assignment")
    @PreAuthorize("hasAnyAuthority('MERCHANT_ORDER_VIEW','MERCHANT_ORDERS_VIEW')")
    MerchantCourierAssignmentService.AssignmentInfo assignment(@AuthenticationPrincipal IdentityPrincipal p,@PathVariable UUID id){return couriers.info(p,id);}

    @PostMapping("/orders/{id}/delivery/auto-assign")
    @PreAuthorize("hasAuthority('MERCHANT_DELIVERY_ASSIGN')")
    MerchantCourierAssignmentService.AssignmentInfo autoAssign(@AuthenticationPrincipal IdentityPrincipal p,@PathVariable UUID id){return couriers.autoAssign(p,id);}

    @GetMapping("/orders/{id}/delivery/available-couriers")
    @PreAuthorize("hasAuthority('MERCHANT_DELIVERY_VIEW_COURIERS')")
    PageResponse<MerchantCourierAssignmentService.AvailableCourier> available(@AuthenticationPrincipal IdentityPrincipal p,@PathVariable UUID id,@RequestParam(defaultValue="")String search,@RequestParam(defaultValue="0")int page,@RequestParam(defaultValue="20")int size){return couriers.available(p,id,search,page,size);}

    @PostMapping("/orders/{id}/delivery/manual-assign")
    @PreAuthorize("hasAuthority('MERCHANT_DELIVERY_ASSIGN')")
    MerchantCourierAssignmentService.AssignmentInfo manualAssign(@AuthenticationPrincipal IdentityPrincipal p,@PathVariable UUID id,@Valid @RequestBody ManualAssignment q){return couriers.manualAssign(p,id,q.courierId());}

    @PostMapping("/orders/{id}/hand-to-courier")
    @PreAuthorize("hasAuthority('MERCHANT_ORDER_HAND_TO_COURIER')")
    MerchantCourierAssignmentService.AssignmentInfo hand(@AuthenticationPrincipal IdentityPrincipal p,@PathVariable UUID id){return couriers.handToCourier(p,id);}

    @GetMapping("/reports/summary")
    @PreAuthorize("hasAuthority('MERCHANT_REPORTS_VIEW')")
    MerchantPortalService.Report report(@AuthenticationPrincipal IdentityPrincipal p, @RequestParam UUID merchantId,
        @RequestParam(required=false) UUID branchId, @RequestParam(defaultValue="30") int days) {
        return service.report(p, merchantId, branchId, days);
    }

    @PatchMapping("/orders/{id}/status")
    @PreAuthorize("hasAuthority('MERCHANT_ORDERS_MANAGE')")
    MerchantPortalService.OrderDetail transition(@AuthenticationPrincipal IdentityPrincipal p, @PathVariable UUID id,
        @Valid @RequestBody Transition q) { return service.transition(p, id, q.status(), q.expectedVersion(), q.reason()); }

    @PutMapping("/branches/{id}/pause")
    @PreAuthorize("hasAuthority('MERCHANT_BRANCH_OPERATE')")
    MerchantPortalService.Branch pause(@AuthenticationPrincipal IdentityPrincipal p, @PathVariable UUID id,
        @Valid @RequestBody Pause q) { return service.pause(p, id, q.minutes(), q.reason()); }
}
