package com.delivery.platform.delivery.route;

import java.math.BigDecimal;

public interface RouteProvider {
    RouteResult route(BigDecimal originLatitude, BigDecimal originLongitude,
                      BigDecimal destinationLatitude, BigDecimal destinationLongitude);
    String code();

    record RouteResult(String polyline, double distanceMeters, double durationSeconds) {}
}
