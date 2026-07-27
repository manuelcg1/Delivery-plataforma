package com.delivery.platform.identity.auth.application;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class AuthServiceTest {

    @Test
    void tenantRegistrationGrantsPermissionsIdempotently() {
        assertThat(AuthService.GRANT_ALL_PERMISSIONS_SQL)
                .contains("role_permissions(role_id,permission_id)")
                .containsIgnoringCase("on conflict do nothing");
    }
}
