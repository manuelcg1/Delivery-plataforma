package com.delivery.platform.identity.auth.api;

import com.delivery.platform.common.GlobalExceptionHandler;
import com.delivery.platform.identity.auth.application.AuthService;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

class MobileAuthValidationTest {
    @Test void administrativeProfileIsRejectedAsBadRequestWithoutRegisteringUser() throws Exception {
        var service=mock(AuthService.class);
        var mvc=MockMvcBuilders.standaloneSetup(new AuthController(service))
            .setControllerAdvice(new GlobalExceptionHandler()).build();
        mvc.perform(post("/api/v1/auth/register-mobile").contentType(MediaType.APPLICATION_JSON)
            .content("{\"profile\":\"TENANT_ADMIN\"}"))
            .andExpect(status().isBadRequest()).andExpect(jsonPath("$.error").value("INVALID_REQUEST_BODY"));
        verifyNoInteractions(service);
    }
}
