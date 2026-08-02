package com.delivery.platform.delivery.api;

import com.delivery.platform.common.PageResponse;
import com.delivery.platform.delivery.application.DeliveryCoverageService;
import com.delivery.platform.delivery.application.DeliveryService;
import com.delivery.platform.delivery.application.DeliveryService.*;
import com.delivery.platform.delivery.domain.DeliveryTypes.*;
import com.delivery.platform.identity.security.IdentityPrincipal;
import com.delivery.platform.merchant.application.MerchantCourierAssignmentService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.util.*;

@RestController
@RequestMapping("/api/v1")
public class DeliveryController {
    private final DeliveryService service;
    private final MerchantCourierAssignmentService assignments;

    public DeliveryController(DeliveryService service, MerchantCourierAssignmentService assignments) {
        this.service = service;
        this.assignments = assignments;
    }

    public record DeliveryQuoteRequest(@NotNull UUID merchantId,@NotNull UUID branchId,@NotNull UUID addressId,@NotNull @PositiveOrZero BigDecimal orderSubtotal) {}
    public record CreateDeliveryRequest(@NotNull Type deliveryType,@Size(max=500) String pickupNotes,@Size(max=500) String deliveryNotes) {}
    public record AssignCourierRequest(UUID courierId) {}
    public record UpdateDeliveryStatusRequest(@NotNull Status status,@Size(max=500) String notes) {}
    public record CourierRequest(@NotNull UUID userId,@Pattern(regexp="BICYCLE|MOTORCYCLE|CAR|VAN|WALKER|OTHER") String vehicleType,String phone,@Min(1) int maxActiveDeliveries) {}
    public record AvailabilityRequest(@Pattern(regexp="ONLINE|OFFLINE|BUSY|PAUSED") String status,UUID zoneId,UUID branchId) {}
    public record ZoneRequest(@NotNull UUID merchantId,UUID branchId,@NotBlank String name,String description,@Pattern(regexp="DISTRICT|CITY|POSTAL_CODE|RADIUS") String zoneType,@NotBlank String areas,boolean active,@PositiveOrZero BigDecimal minimumOrderAmount,@PositiveOrZero BigDecimal baseDeliveryFee,@Pattern(regexp="[A-Z]{3}") String currency,@Min(1) int estimatedMinutes) {}

    @PostMapping("/delivery/quote") @PreAuthorize("hasAuthority('DELIVERY_VIEW')")
    DeliveryCoverageService.Quote quote(@AuthenticationPrincipal IdentityPrincipal p,@Valid @RequestBody DeliveryQuoteRequest q){return service.quote(p,q.merchantId(),q.branchId(),q.addressId(),q.orderSubtotal());}
    @PostMapping("/orders/{id}/delivery") @PreAuthorize("hasAuthority('DELIVERY_CREATE')")
    Delivery create(@AuthenticationPrincipal IdentityPrincipal p,@PathVariable UUID id,@RequestHeader("Idempotency-Key") String key,@Valid @RequestBody CreateDeliveryRequest q){return service.create(p,id,q.deliveryType(),q.pickupNotes(),q.deliveryNotes(),key);}
    @GetMapping("/orders/{id}/delivery") @PreAuthorize("hasAuthority('DELIVERY_VIEW')")
    Delivery order(@AuthenticationPrincipal IdentityPrincipal p,@PathVariable UUID id){return service.list(p,null,0,100).content().stream().filter(x->x.orderId().equals(id)).findFirst().orElse(null);}
    @GetMapping("/deliveries") @PreAuthorize("hasAuthority('DELIVERY_VIEW')")
    PageResponse<Delivery> list(@AuthenticationPrincipal IdentityPrincipal p,@RequestParam(required=false) String status,@RequestParam(defaultValue="0") int page,@RequestParam(defaultValue="20") int size){return service.list(p,status,page,size);}
    @GetMapping("/deliveries/{id}") @PreAuthorize("hasAuthority('DELIVERY_VIEW')")
    Delivery one(@AuthenticationPrincipal IdentityPrincipal p,@PathVariable UUID id){return service.one(p,id);}
    @GetMapping("/deliveries/{id}/history") @PreAuthorize("hasAuthority('DELIVERY_VIEW')")
    List<History> history(@AuthenticationPrincipal IdentityPrincipal p,@PathVariable UUID id){return service.history(p,id);}
    @PostMapping("/deliveries/{id}/assign") @PreAuthorize("hasAuthority('DELIVERY_ASSIGN')")
    Delivery assign(@AuthenticationPrincipal IdentityPrincipal p,@PathVariable UUID id,@RequestHeader("Idempotency-Key") String key,@RequestBody AssignCourierRequest q){assignments.assignDelivery(p,id,q.courierId(),"MANUAL",key);return service.one(p,id);}
    @PostMapping("/deliveries/{id}/auto-assign") @PreAuthorize("hasAuthority('DELIVERY_ASSIGN')")
    Delivery auto(@AuthenticationPrincipal IdentityPrincipal p,@PathVariable UUID id,@RequestHeader("Idempotency-Key") String key){assignments.assignDelivery(p,id,null,"AUTOMATIC",key);return service.one(p,id);}
    @PostMapping({"/deliveries/{id}/status","/deliveries/{id}/accept","/deliveries/{id}/reject","/deliveries/{id}/cancel"}) @PreAuthorize("hasAuthority('DELIVERY_UPDATE_STATUS')")
    Delivery status(@AuthenticationPrincipal IdentityPrincipal p,@PathVariable UUID id,@Valid @RequestBody UpdateDeliveryStatusRequest q){return service.status(p,id,q.status(),q.notes());}

    @GetMapping("/couriers") @PreAuthorize("hasAuthority('COURIER_VIEW')") List<Courier> couriers(@AuthenticationPrincipal IdentityPrincipal p){return service.couriers(p,false);}
    @GetMapping("/couriers/available") @PreAuthorize("hasAuthority('COURIER_VIEW')") List<Courier> available(@AuthenticationPrincipal IdentityPrincipal p){return service.couriers(p,true);}
    @GetMapping("/couriers/candidates") @PreAuthorize("hasAuthority('COURIER_MANAGE')") List<CourierCandidate> candidates(@AuthenticationPrincipal IdentityPrincipal p){return service.courierCandidates(p);}
    @PostMapping("/couriers") @PreAuthorize("hasAuthority('COURIER_MANAGE')") Courier courier(@AuthenticationPrincipal IdentityPrincipal p,@Valid @RequestBody CourierRequest q){return service.createCourier(p,q.userId(),q.vehicleType(),q.phone(),q.maxActiveDeliveries());}
    @PutMapping("/couriers/{id}/availability") @PreAuthorize("hasAuthority('COURIER_AVAILABILITY_MANAGE')") void availability(@AuthenticationPrincipal IdentityPrincipal p,@PathVariable UUID id,@Valid @RequestBody AvailabilityRequest q){service.availability(p,id,q.status(),q.zoneId(),q.branchId());}
    @GetMapping("/delivery-zones") @PreAuthorize("hasAuthority('DELIVERY_ZONE_VIEW')") List<Zone> zones(@AuthenticationPrincipal IdentityPrincipal p){return service.zones(p);}
    @PostMapping("/delivery-zones") @PreAuthorize("hasAuthority('DELIVERY_ZONE_MANAGE')") Zone zone(@AuthenticationPrincipal IdentityPrincipal p,@Valid @RequestBody ZoneRequest q){return service.saveZone(p,null,q.merchantId(),q.branchId(),q.name(),q.description(),q.zoneType(),q.areas(),q.active(),q.minimumOrderAmount(),q.baseDeliveryFee(),q.currency(),q.estimatedMinutes());}
    @PutMapping("/delivery-zones/{id}") @PreAuthorize("hasAuthority('DELIVERY_ZONE_MANAGE')") Zone zone(@AuthenticationPrincipal IdentityPrincipal p,@PathVariable UUID id,@Valid @RequestBody ZoneRequest q){return service.saveZone(p,id,q.merchantId(),q.branchId(),q.name(),q.description(),q.zoneType(),q.areas(),q.active(),q.minimumOrderAmount(),q.baseDeliveryFee(),q.currency(),q.estimatedMinutes());}
    @DeleteMapping("/delivery-zones/{id}") @PreAuthorize("hasAuthority('DELIVERY_ZONE_MANAGE')") void delete(@AuthenticationPrincipal IdentityPrincipal p,@PathVariable UUID id){service.deleteZone(p,id);}
}
