package com.delivery.platform.delivery.application;import java.util.*;public interface CourierAssignmentStrategy{Optional<UUID> select(UUID tenantId,UUID branchId,UUID zoneId);}
