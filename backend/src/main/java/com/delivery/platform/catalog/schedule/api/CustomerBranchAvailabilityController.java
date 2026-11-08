package com.delivery.platform.catalog.schedule.api;
import com.delivery.platform.catalog.schedule.application.BranchHoursService;
import com.delivery.platform.identity.security.IdentityPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import java.util.UUID;
@RestController
@RequestMapping("/api/v1/customer/branches")
@PreAuthorize("hasRole('CUSTOMER')")
public class CustomerBranchAvailabilityController {
 private final BranchHoursService hours;
 public CustomerBranchAvailabilityController(BranchHoursService hours){this.hours=hours;}
 @GetMapping("/{branchId}/availability")
 public BranchHoursService.Availability availability(@AuthenticationPrincipal IdentityPrincipal principal,@PathVariable UUID branchId){return hours.availability(principal.tenantId(),branchId);}
}
