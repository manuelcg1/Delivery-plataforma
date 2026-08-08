package com.delivery.platform.tracking.courier;

import com.delivery.platform.config.SecurityConfig;
import com.delivery.platform.identity.security.IdentityPrincipal;
import com.delivery.platform.identity.security.JwtService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.test.web.servlet.MockMvc;

import java.util.Set;
import java.util.UUID;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(CourierDeliveryRouteController.class)
@Import(SecurityConfig.class)
class CourierDeliveryRouteSecurityTest {
    @Autowired MockMvc mvc;
    @MockBean CourierDeliveryRouteService service;
    @MockBean JwtService jwt;
    private final UUID delivery = UUID.randomUUID(), tenant = UUID.randomUUID();

    @Test void unauthenticatedRequestIsUnauthorized() throws Exception {
        mvc.perform(get("/api/v1/courier/deliveries/{id}/route", delivery))
                .andExpect(status().isUnauthorized());
    }

    @Test void customerCannotReadCourierRoute() throws Exception {
        when(jwt.parse("customer")).thenReturn(principal("CUSTOMER", "DELIVERY_VIEW"));
        mvc.perform(get("/api/v1/courier/deliveries/{id}/route", delivery)
                        .header("Authorization", "Bearer customer"))
                .andExpect(status().isForbidden());
    }

    @Test void courierWithDeliveryAccessCanReadAssignedRoute() throws Exception {
        when(jwt.parse("courier")).thenReturn(principal("COURIER", "DELIVERY_VIEW"));
        when(service.get(eq(delivery), any())).thenReturn(null);
        mvc.perform(get("/api/v1/courier/deliveries/{id}/route", delivery)
                        .header("Authorization", "Bearer courier"))
                .andExpect(status().isOk());
    }

    private IdentityPrincipal principal(String role, String permission) {
        return new IdentityPrincipal(UUID.randomUUID(), tenant, "elite", Set.of(role), Set.of(permission));
    }
}
