package com.delivery.platform.delivery.application;

import java.math.BigDecimal;
import java.math.RoundingMode;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

@Service
public class DeliveryEtaService {
    public record Estimate(int preparationMinutes, int assignmentMinutes,
                           int courierToMerchantMinutes, int merchantToCustomerMinutes,
                           int estimatedMinutes, int minimumMinutes, int maximumMinutes) {}

    private final int assignmentMinutes;
    private final int courierToMerchantMinutes;
    private final BigDecimal averageSpeedKph;
    private final int uncertaintyMinutes;

    public DeliveryEtaService(
            @Value("${delivery.eta.assignment-minutes:5}") int assignmentMinutes,
            @Value("${delivery.eta.courier-to-merchant-minutes:10}") int courierToMerchantMinutes,
            @Value("${delivery.eta.average-speed-kph:25}") BigDecimal averageSpeedKph,
            @Value("${delivery.eta.uncertainty-minutes:5}") int uncertaintyMinutes) {
        if (assignmentMinutes < 0 || courierToMerchantMinutes < 0 || uncertaintyMinutes < 0
                || averageSpeedKph == null || averageSpeedKph.signum() <= 0) {
            throw new IllegalArgumentException("La configuración ETA debe contener valores positivos");
        }
        this.assignmentMinutes = assignmentMinutes;
        this.courierToMerchantMinutes = courierToMerchantMinutes;
        this.averageSpeedKph = averageSpeedKph;
        this.uncertaintyMinutes = uncertaintyMinutes;
    }

    public Estimate quote(int preparationMinutes, BigDecimal distanceKm) {
        int preparation = Math.max(0, preparationMinutes);
        int delivery = travelMinutes(distanceKm);
        int total = preparation + assignmentMinutes + courierToMerchantMinutes + delivery;
        return new Estimate(preparation, assignmentMinutes, courierToMerchantMinutes, delivery,
                total, Math.max(1, total - uncertaintyMinutes), total + uncertaintyMinutes);
    }

    public int remainingMinutes(BigDecimal distanceKm) {
        return Math.max(1, travelMinutes(distanceKm));
    }

    private int travelMinutes(BigDecimal distanceKm) {
        if (distanceKm == null || distanceKm.signum() <= 0) return 0;
        return distanceKm.multiply(BigDecimal.valueOf(60))
                .divide(averageSpeedKph, 0, RoundingMode.UP).intValue();
    }
}
