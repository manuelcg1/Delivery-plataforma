package com.delivery.platform.tracking.customer;

import com.delivery.platform.common.ApiException;
import com.delivery.platform.common.GlobalExceptionHandler;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import java.time.Instant;
import java.util.UUID;

import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

class CustomerOrderTrackingControllerTest {
    private CustomerOrderTrackingService service;
    private MockMvc mvc;
    private UUID order;

    @BeforeEach void setUp() {
        service = mock(CustomerOrderTrackingService.class);
        mvc = MockMvcBuilders.standaloneSetup(new CustomerOrderTrackingController(service))
                .setControllerAdvice(new GlobalExceptionHandler()).build();
        order = UUID.randomUUID();
    }

    @Test void ownOrderWithLocationReturnsExactContract() throws Exception {
        UUID delivery = UUID.randomUUID(), courier = UUID.randomUUID();
        when(service.getTracking(eq(order), any())).thenReturn(new CustomerOrderTrackingResponse(order, delivery,
                "IN_TRANSIT", new CourierTrackingSummary(courier, "Carlos M."),
                new TrackingLocationResponse(-12.0464, -77.0428, 25.0, 180.0, 8.0, 120.0,
                        Instant.parse("2026-07-31T15:30:00Z")),
                Instant.parse("2026-07-31T15:30:01Z"), true, false));
        mvc.perform(get("/api/v1/customer/orders/{orderId}/tracking", order))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.orderId").value(order.toString()))
                .andExpect(jsonPath("$.deliveryId").value(delivery.toString()))
                .andExpect(jsonPath("$.courier.displayName").value("Carlos M."))
                .andExpect(jsonPath("$.location.accuracy").value(8.0))
                .andExpect(jsonPath("$.trackingActive").value(true))
                .andExpect(jsonPath("$.stale").value(false));
    }

    @Test void ownOrderWithoutLocationReturnsOk() throws Exception {
        when(service.getTracking(eq(order), any())).thenReturn(new CustomerOrderTrackingResponse(order,
                UUID.randomUUID(), "PICKED_UP", null, null, null, true, true));
        mvc.perform(get("/api/v1/customer/orders/{orderId}/tracking", order))
                .andExpect(status().isOk()).andExpect(jsonPath("$.location").doesNotExist())
                .andExpect(jsonPath("$.trackingActive").value(true));
    }

    @Test void deliveredOrderIsInactive() throws Exception {
        when(service.getTracking(eq(order), any())).thenReturn(new CustomerOrderTrackingResponse(order,
                UUID.randomUUID(), "DELIVERED", null, null, null, false, true));
        mvc.perform(get("/api/v1/customer/orders/{orderId}/tracking", order))
                .andExpect(status().isOk()).andExpect(jsonPath("$.trackingActive").value(false));
    }

    @Test void foreignAndMissingOrderAreNotFound() throws Exception {
        when(service.getTracking(eq(order), any())).thenThrow(new ApiException(HttpStatus.NOT_FOUND,
                "ORDER_TRACKING_NOT_FOUND", "Seguimiento no encontrado"));
        mvc.perform(get("/api/v1/customer/orders/{orderId}/tracking", order))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.error").value("ORDER_TRACKING_NOT_FOUND"));
    }

    @Test void invalidOrderIdIsBadRequest() throws Exception {
        mvc.perform(get("/api/v1/customer/orders/not-a-uuid/tracking"))
                .andExpect(status().isBadRequest());
        verifyNoInteractions(service);
    }
}
