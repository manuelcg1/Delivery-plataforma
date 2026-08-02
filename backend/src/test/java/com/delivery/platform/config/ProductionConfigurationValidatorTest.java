package com.delivery.platform.config;

import org.junit.jupiter.api.Test;
import org.springframework.context.annotation.AnnotationConfigApplicationContext;
import org.springframework.core.env.MapPropertySource;

import java.util.Map;

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
                "CASH_ONLY", false, "");

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
                "SIMULATED", false, "");

        assertThatThrownBy(validator::validate)
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("Invalid production configuration");
    }

    @Test
    void requiresGoogleKeyOnlyWhenPlacesIsEnabled() {
        var validator = new ProductionConfigurationValidator(
                "a-strong-random-jwt-secret-that-is-more-than-forty-eight-characters",
                "https://admin.example.com", "https://admin.example.com",
                "a-strong-random-webhook-secret-more-than-thirty-two",
                "https://media.example.com", "CASH_ONLY", true, "");

        assertThatThrownBy(validator::validate)
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("GOOGLE_MAPS_API_KEY");
    }

    @Test
    void springCreatesTheValidatorBeanWithConstructorInjection() {
        try (var context = new AnnotationConfigApplicationContext()) {
            context.getEnvironment().setActiveProfiles("prod");
            context.getEnvironment().getPropertySources().addFirst(
                    new MapPropertySource("test-production-settings", Map.of(
                            "identity.jwt-secret", "a-strong-random-jwt-secret-that-is-more-than-forty-eight-characters",
                            "identity.frontend-url", "https://admin.example.com",
                            "CORS_ALLOWED_ORIGINS", "https://admin.example.com",
                            "PAYMENT_WEBHOOK_SECRET", "a-strong-random-webhook-secret-more-than-thirty-two",
                            "MINIO_PUBLIC_ENDPOINT", "https://media.example.com",
                            "PAYMENT_PROVIDER", "CASH_ONLY",
                            "google.places.enabled", "false"
                    )));
            context.register(ProductionConfigurationValidator.class);

            assertThatCode(context::refresh).doesNotThrowAnyException();
            assertThatCode(() -> context.getBean(ProductionConfigurationValidator.class))
                    .doesNotThrowAnyException();
        }
    }
}
