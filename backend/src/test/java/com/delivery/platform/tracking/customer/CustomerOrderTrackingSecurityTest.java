package com.delivery.platform.tracking.customer;

import com.delivery.platform.config.SecurityConfig;
import com.delivery.platform.identity.security.IdentityPrincipal;
import com.delivery.platform.identity.security.JwtService;
import com.delivery.platform.identity.security.IdentityPrincipalLoader;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.test.web.servlet.MockMvc;

import java.util.Set;
import java.util.UUID;

import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(CustomerOrderTrackingController.class)
@Import(SecurityConfig.class)
class CustomerOrderTrackingSecurityTest {
    @Autowired MockMvc mvc;
    @MockBean CustomerOrderTrackingService service;
    @MockBean JwtService jwt;
    @MockBean IdentityPrincipalLoader principalLoader;
    private final UUID order = UUID.randomUUID(), tenant = UUID.randomUUID();

    @Test void unauthenticatedRequestIsUnauthorized() throws Exception {
        mvc.perform(get("/api/v1/customer/orders/{orderId}/tracking", order))
                .andExpect(status().isUnauthorized());
    }

    @Test void merchantAndCourierAreForbiddenFromCustomerEndpoint() throws Exception {
        for (String role : new String[]{"MERCHANT_OPERATOR", "COURIER"}) {
            var tokenPrincipal = principal(role);
            when(jwt.parse(role)).thenReturn(tokenPrincipal);
            mvc.perform(get("/api/v1/customer/orders/{orderId}/tracking", order)
                            .header("Authorization", "Bearer " + role))
                    .andExpect(status().isForbidden());
        }
    }

    @Test void customerRoleCanUseEndpoint() throws Exception {
        var tokenPrincipal = principal("CUSTOMER");
        when(jwt.parse("customer")).thenReturn(tokenPrincipal);
        when(service.getTracking(eq(order), any())).thenReturn(new CustomerOrderTrackingResponse(
                order, UUID.randomUUID(), "PICKED_UP", null, null, null, true, true));
        mvc.perform(get("/api/v1/customer/orders/{orderId}/tracking", order)
                        .header("Authorization", "Bearer customer"))
                .andExpect(status().isOk());
    }

    private IdentityPrincipal principal(String role) {
        var principal = new IdentityPrincipal(UUID.randomUUID(), tenant, "elite", Set.of(role), Set.of("TRACKING_VIEW"));
        when(principalLoader.load(principal.userId(), tenant)).thenReturn(java.util.Optional.of(principal));
        return principal;
    }
}
