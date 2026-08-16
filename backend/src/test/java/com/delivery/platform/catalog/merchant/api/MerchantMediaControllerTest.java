package com.delivery.platform.catalog.merchant.api;

import com.delivery.platform.catalog.media.application.MerchantMediaService;
import com.delivery.platform.catalog.media.application.MerchantMediaService.MerchantImage;
import com.delivery.platform.catalog.media.application.MerchantMediaService.Type;
import com.delivery.platform.identity.security.IdentityPrincipal;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

class MerchantMediaControllerTest {
    private MerchantMediaService service;
    private MockMvc mvc;
    private IdentityPrincipal principal;

    @BeforeEach
    void setUp() {
        service = mock(MerchantMediaService.class);
        principal = new IdentityPrincipal(UUID.randomUUID(), UUID.randomUUID(), "tenant", Set.of("TENANT_ADMIN"), Set.of("CATALOG_MEDIA_UPLOAD"));
        mvc = MockMvcBuilders.standaloneSetup(new MerchantMediaController(service)).build();
    }

    @Test
    void forwardsAuthenticatedPrincipalAndMerchantToLogoService() {
        UUID merchant = UUID.randomUUID();
        when(service.upload(any(), eq(merchant), eq(Type.LOGO), any()))
                .thenReturn(new MerchantImage("LOGO", "https://media.example/logo"));
        MockMultipartFile file = new MockMultipartFile("file", "logo.webp", "image/webp", new byte[]{1});

        MerchantImage result = new MerchantMediaController(service).logo(principal, merchant, file);

        org.assertj.core.api.Assertions.assertThat(result.url()).isEqualTo("https://media.example/logo");
        verify(service).upload(principal, merchant, Type.LOGO, file);
    }

    @Test
    void uploadsBannerThroughDedicatedEndpoint() throws Exception {
        UUID merchant = UUID.randomUUID();
        when(service.upload(any(), eq(merchant), eq(Type.BANNER), any()))
                .thenReturn(new MerchantImage("BANNER", "https://media.example/banner"));

        mvc.perform(multipart("/api/v1/merchants/{id}/banner", merchant)
                        .file(new MockMultipartFile("file", "banner.jpg", "image/jpeg", new byte[]{1})))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.type").value("BANNER"));
    }
}
