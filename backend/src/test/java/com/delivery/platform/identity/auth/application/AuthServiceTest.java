package com.delivery.platform.identity.auth.application;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class AuthServiceTest {

    @Test
    void tenantRegistrationGrantsPermissionsIdempotently() {
        assertThat(AuthService.GRANT_ALL_PERMISSIONS_SQL)
                .contains("role_permissions(role_id,permission_id)")
                .contains("module <> 'PLATFORM'")
                .containsIgnoringCase("on conflict do nothing");
    }

    @Test void normalizesPeruvianMobilePhone() {
        assertThat(AuthService.normalizeMobilePhone("987 654-321")).isEqualTo("+51987654321");
        assertThat(AuthService.normalizeMobilePhone("+51 (987) 654-321")).isEqualTo("+51987654321");
    }
    @Test void rejectsMissingForeignAndMalformedMobilePhone() {
        for(String phone: new String[]{"", "123456789", "+52987654321", "51987654321", "98765432a", "+519876543210"}) {
            org.assertj.core.api.Assertions.assertThatThrownBy(() -> AuthService.normalizeMobilePhone(phone))
                .isInstanceOf(com.delivery.platform.common.ApiException.class);
        }
        org.assertj.core.api.Assertions.assertThatThrownBy(() -> AuthService.normalizeMobilePhone(null))
            .isInstanceOf(com.delivery.platform.common.ApiException.class);
    }
    @Test void resetEmailUsesExplicitConfiguredSender() {
        var service = new AuthService(null,null,null,null,null,null);
        service.mailFrom = "notificaciones@cerka.site";
        service.frontendUrl = "https://admin.example.test";
        var message = service.resetMessage("customer@example.test", "test-token");
        assertThat(message.getFrom()).isEqualTo("notificaciones@cerka.site");
        assertThat(message.getTo()).containsExactly("customer@example.test");
        assertThat(message.getText()).contains("https://admin.example.test/reset-password?token=test-token");
    }
}
