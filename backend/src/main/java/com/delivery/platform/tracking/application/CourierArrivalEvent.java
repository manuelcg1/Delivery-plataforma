package com.delivery.platform.tracking.application;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public record CourierArrivalEvent(UUID tenantId, UUID deliveryId, UUID orderId, UUID customerId,
                                  UUID courierId, BigDecimal distanceMeters, Instant detectedAt,
                                  String method) {}
