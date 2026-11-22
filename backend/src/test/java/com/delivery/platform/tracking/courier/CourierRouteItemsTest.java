package com.delivery.platform.tracking.courier;

import java.lang.reflect.RecordComponent;
import java.util.Arrays;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class CourierRouteItemsTest {
    @Test
    void routeIncludesProductsWithoutPrices() {
        assertThat(names(CourierDeliveryRouteService.RouteView.class.getRecordComponents())).contains("items");
        assertThat(names(CourierDeliveryRouteService.RouteItem.class.getRecordComponents()))
                .containsExactly("productName", "quantity", "options", "notes");
        assertThat(names(CourierDeliveryRouteService.RouteItemOption.class.getRecordComponents()))
                .containsExactly("groupName", "itemName");
    }

    private static java.util.List<String> names(RecordComponent[] components) {
        return Arrays.stream(components).map(RecordComponent::getName).toList();
    }
}
