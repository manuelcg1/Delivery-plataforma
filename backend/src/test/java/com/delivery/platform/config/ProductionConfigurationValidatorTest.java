package com.delivery.platform.config;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class ProductionConfigurationValidatorTest {
    @Test
    void acceptsStrictProductionConfiguration() {
        var validator = new ProductionConfigurationValidator(
                "a-strong-random-jwt-secret-that-is-more-than-forty-eight-characters",
                "https://admin.example.com",
                "https://admin.example.com,https://merchant.example.com",
                "a-strong-random-webhook-secret-more-than-thirty-two",
                "https://media.example.com",
                "CASH_ONLY");

        assertThatCode(validator::validate).doesNotThrowAnyException();
    }

    @Test
    void rejectsDevelopmentValues() {
        var validator = new ProductionConfigurationValidator(
                "development-only-secret-key-change-me-32-bytes",
                "http://localhost:3000",
                "http://localhost:3000",
                "local-simulated-secret",
                "http://localhost:9000",
                "SIMULATED");

        assertThatThrownBy(validator::validate)
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("Invalid production configuration");
    }
}
