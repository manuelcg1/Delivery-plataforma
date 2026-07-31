package com.delivery.platform.tracking.realtime;

import java.util.UUID;

record PendingCourierTrackingEvent(
        UUID tenantId,
        UUID customerUserId,
        UUID courierId,
        CourierTrackingEvent event
) {}
