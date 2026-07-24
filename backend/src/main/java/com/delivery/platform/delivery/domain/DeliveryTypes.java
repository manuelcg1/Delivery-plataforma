package com.delivery.platform.delivery.domain;

import com.delivery.platform.common.ApiException;
import org.springframework.http.HttpStatus;

import java.util.Map;
import java.util.Set;

public final class DeliveryTypes {
    private DeliveryTypes() {}

    public enum Type { MERCHANT_DELIVERY, PLATFORM_DELIVERY, PICKUP }

    public enum Status {
        PENDING, SEARCHING_COURIER, ASSIGNED, ACCEPTED, ARRIVED_AT_MERCHANT,
        PICKED_UP, IN_TRANSIT, ARRIVED_AT_CUSTOMER, DELIVERED, FAILED,
        CANCELLED, REJECTED, EXPIRED
    }

    private static final Map<Status, Set<Status>> ALLOWED = Map.ofEntries(
            Map.entry(Status.PENDING, Set.of(Status.SEARCHING_COURIER, Status.CANCELLED)),
            Map.entry(Status.SEARCHING_COURIER, Set.of(Status.ASSIGNED, Status.EXPIRED, Status.CANCELLED)),
            Map.entry(Status.ASSIGNED, Set.of(Status.ACCEPTED, Status.REJECTED, Status.CANCELLED)),
            Map.entry(Status.ACCEPTED, Set.of(Status.ARRIVED_AT_MERCHANT, Status.PICKED_UP, Status.CANCELLED)),
            Map.entry(Status.ARRIVED_AT_MERCHANT, Set.of(Status.PICKED_UP)),
            Map.entry(Status.PICKED_UP, Set.of(Status.IN_TRANSIT, Status.FAILED)),
            Map.entry(Status.IN_TRANSIT, Set.of(Status.ARRIVED_AT_CUSTOMER, Status.DELIVERED, Status.FAILED)),
            Map.entry(Status.ARRIVED_AT_CUSTOMER, Set.of(Status.DELIVERED, Status.FAILED))
    );

    public static void validate(Status from, Status to) {
        if (!ALLOWED.getOrDefault(from, Set.of()).contains(to)) {
            throw new ApiException(HttpStatus.CONFLICT, "DELIVERY_INVALID_STATE",
                    "Transición no permitida: " + from + " → " + to);
        }
    }
}
