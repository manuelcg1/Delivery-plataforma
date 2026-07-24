package com.delivery.platform.platform.api;

import com.delivery.platform.common.PageResponse;
import com.delivery.platform.identity.security.IdentityPrincipal;
import com.delivery.platform.platform.application.PlatformAdminService;
import com.delivery.platform.platform.application.PlatformAdminService.*;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/platform")
@PreAuthorize("hasAuthority('PLATFORM_MANAGE')")
public class PlatformAdminController {
    public record SettingRequest(@NotBlank String value) {}
    private final PlatformAdminService service;
    public PlatformAdminController(PlatformAdminService service){this.service=service;}

    @GetMapping("/overview") Overview overview(){return service.overview();}
    @GetMapping("/orders") PageResponse<GlobalOrder> orders(@RequestParam(required=false)UUID merchantId,@RequestParam(required=false)UUID branchId,@RequestParam(required=false)UUID customerId,@RequestParam(required=false)UUID courierId,@RequestParam(required=false)String status,@RequestParam(required=false)String payment,@RequestParam(required=false)String from,@RequestParam(required=false)String to,@RequestParam(defaultValue="")String city,@RequestParam(defaultValue="")String zone,@RequestParam(defaultValue="0")int page,@RequestParam(defaultValue="50")int size){return service.orders(merchantId,branchId,customerId,courierId,status,payment,from,to,city,zone,page,size);}
    @GetMapping("/merchants") List<MerchantRow> merchants(){return service.merchants();}
    @GetMapping("/customers") List<CustomerRow> customers(){return service.customers();}
    @GetMapping("/couriers") List<CourierRow> couriers(){return service.couriers();}
    @GetMapping("/transactions") List<TransactionRow> transactions(){return service.transactions();}
    @GetMapping("/tenants") List<TenantRow> tenants(){return service.tenants();}
    @GetMapping("/branches") List<BranchRow> branches(){return service.branches();}
    @GetMapping("/roles") List<RoleRow> roles(){return service.roles();}
    @GetMapping("/permissions") List<PermissionRow> permissions(){return service.permissions();}
    @GetMapping("/audit") List<AuditRow> audit(){return service.audit();}
    @GetMapping("/settings") List<Setting> settings(){return service.settings();}
    @PutMapping("/settings/{key}") Setting setting(@AuthenticationPrincipal IdentityPrincipal p,@PathVariable String key,@Valid @RequestBody SettingRequest q){return service.setting(p,key,q.value());}
}
