package com.delivery.platform.delivery.application;

import java.util.Optional;
import java.util.UUID;

public interface CourierAssignmentStrategy {
    Optional<UUID> select(UUID tenantId, UUID branchId, UUID zoneId);

    /** Igual que {@link #select(UUID, UUID, UUID)} pero sin considerar al repartidor indicado. */
    Optional<UUID> selectExcluding(UUID tenantId, UUID branchId, UUID zoneId, UUID excludedCourierId);
}
