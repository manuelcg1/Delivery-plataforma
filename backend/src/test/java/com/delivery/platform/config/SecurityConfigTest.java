package com.delivery.platform.config;

import com.delivery.platform.identity.security.JwtService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpStatus;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(SecurityConfigTest.MobileAuthEndpoints.class)
@Import({SecurityConfig.class, SecurityConfigTest.MobileAuthEndpoints.class})
class SecurityConfigTest {
    @Autowired MockMvc mockMvc;
    @MockBean JwtService jwtService;

    @Test
    void permitsMobileAuthenticationEndpointsWithoutBearerToken() throws Exception {
        for (String endpoint : new String[]{
                "/api/v1/auth/register-customer",
                "/api/v1/auth/login-mobile",
                "/api/v1/auth/refresh-mobile"
        }) {
            mockMvc.perform(post(endpoint)).andExpect(status().isNoContent());
        }
    }

    @Test
    void permitsActuatorHealthGroupsWithoutBearerToken() throws Exception {
        mockMvc.perform(get("/actuator/health/readiness")).andExpect(status().isInternalServerError());
    }

    @RestController
    static class MobileAuthEndpoints {
        @PostMapping({
                "/api/v1/auth/register-customer",
                "/api/v1/auth/login-mobile",
                "/api/v1/auth/refresh-mobile"
        })
        @ResponseStatus(HttpStatus.NO_CONTENT)
        void mobileAuth() {
        }
    }
}
