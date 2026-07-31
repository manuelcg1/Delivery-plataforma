package com.delivery.platform.tracking.api;

import com.delivery.platform.common.ApiException;
import com.delivery.platform.common.GlobalExceptionHandler;
import com.delivery.platform.tracking.application.TrackingService;
import com.delivery.platform.tracking.application.TrackingService.Location;
import jakarta.validation.Validation;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.validation.beanvalidation.SpringValidatorAdapter;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

class TrackingControllerLocationTest {
    private TrackingService service;
    private MockMvc mvc;

    @BeforeEach
    void setUp() {
        service = mock(TrackingService.class);
        mvc = MockMvcBuilders.standaloneSetup(new TrackingController(service))
                .setControllerAdvice(new GlobalExceptionHandler())
                .setValidator(new SpringValidatorAdapter(
                        Validation.buildDefaultValidatorFactory().getValidator()))
                .build();
    }

    @Test
    void courierWithPickedUpDeliveryIsAcceptedAndKeepsDeliveryAssociation() throws Exception {
        UUID deliveryId = UUID.randomUUID();
        when(service.location(any(), any())).thenReturn(Optional.of(location(deliveryId)));
        mvc.perform(validRequest()).andExpect(status().isAccepted())
                .andExpect(jsonPath("$.deliveryId").value(deliveryId.toString()));
        verify(service).location(any(), argThat(command ->
                command.latitude().compareTo(new BigDecimal("-12.0464")) == 0));
    }

    @Test
    void courierWithInTransitDeliveryIsAccepted() throws Exception {
        when(service.location(any(), any())).thenReturn(Optional.of(location(UUID.randomUUID())));
        mvc.perform(validRequest()).andExpect(status().isAccepted());
    }

    @Test
    void duplicateIsAcceptedWithoutCreatingAResponseBody() throws Exception {
        when(service.location(any(), any())).thenReturn(Optional.empty());
        mvc.perform(validRequest()).andExpect(status().isAccepted());
        verify(service, times(1)).location(any(), any());
    }

    @Test
    void courierWithoutCompatibleDeliveryIsConflict() throws Exception {
        when(service.location(any(), any())).thenThrow(conflict());
        mvc.perform(validRequest()).andExpect(status().isConflict())
                .andExpect(jsonPath("$.error").value("ACTIVE_DELIVERY_NOT_TRACKABLE"));
    }

    @Test
    void deliveredDeliveryIsRejected() throws Exception {
        when(service.location(any(), any())).thenThrow(conflict());
        mvc.perform(validRequest()).andExpect(status().isConflict());
    }

    @Test
    void deliveryAssignedToAnotherCourierIsRejected() throws Exception {
        when(service.location(any(), any())).thenThrow(conflict());
        mvc.perform(validRequest()).andExpect(status().isConflict());
    }

    @Test
    void invalidCoordinatesAreBadRequestBeforeServiceInvocation() throws Exception {
        mvc.perform(post("/api/v1/couriers/location")
                        .contentType("application/json")
                        .content(payload("91", "-77.0428")))
                .andExpect(status().isBadRequest());
        verifyNoInteractions(service);
    }

    private org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder validRequest() {
        return post("/api/v1/couriers/location")
                .contentType("application/json")
                .content(payload("-12.0464", "-77.0428"));
    }

    private String payload(String latitude, String longitude) {
        return """
                {"latitude":%s,"longitude":%s,"accuracy":8,
                 "provider":"gps","gpsTimestamp":"%s"}
                """.formatted(latitude, longitude, Instant.now());
    }

    private ApiException conflict() {
        return new ApiException(HttpStatus.CONFLICT, "ACTIVE_DELIVERY_NOT_TRACKABLE",
                "No existe una entrega activa compatible con el seguimiento");
    }

    private Location location(UUID deliveryId) {
        Instant now = Instant.now();
        return new Location(UUID.randomUUID(), UUID.randomUUID(), deliveryId,
                new BigDecimal("-12.0464"), new BigDecimal("-77.0428"), null, null,
                BigDecimal.valueOf(8), null, "gps", null, now, now);
    }
}
