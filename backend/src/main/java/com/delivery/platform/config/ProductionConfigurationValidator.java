package com.delivery.platform.config;

import jakarta.annotation.PostConstruct;
import java.net.URI;
import java.util.Arrays;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

@Component
@Profile("prod")
public class ProductionConfigurationValidator {
    private final String jwtSecret;
    private final String frontendUrl;
    private final String corsOrigins;
    private final String webhookSecret;
    private final String minioPublicEndpoint;
    private final String paymentProvider;

    public ProductionConfigurationValidator(
            @Value("${identity.jwt-secret}") String jwtSecret,
            @Value("${identity.frontend-url}") String frontendUrl,
            @Value("${CORS_ALLOWED_ORIGINS}") String corsOrigins,
            @Value("${PAYMENT_WEBHOOK_SECRET}") String webhookSecret,
            @Value("${MINIO_PUBLIC_ENDPOINT}") String minioPublicEndpoint,
            @Value("${PAYMENT_PROVIDER:CASH_ONLY}") String paymentProvider) {
        this.jwtSecret = jwtSecret;
        this.frontendUrl = frontendUrl;
        this.corsOrigins = corsOrigins;
        this.webhookSecret = webhookSecret;
        this.minioPublicEndpoint = minioPublicEndpoint;
        this.paymentProvider = paymentProvider;
    }

    @PostConstruct
    void validate() {
        requireSecret("JWT_SECRET", jwtSecret, 48);
        requireSecret("PAYMENT_WEBHOOK_SECRET", webhookSecret, 32);
        requireHttps("FRONTEND_URL", frontendUrl);
        requireHttps("MINIO_PUBLIC_ENDPOINT", minioPublicEndpoint);
        if (corsOrigins.isBlank()) throw invalid("CORS_ALLOWED_ORIGINS must not be empty");
        Arrays.stream(corsOrigins.split(",")).map(String::trim)
                .forEach(origin -> requireHttps("CORS_ALLOWED_ORIGINS", origin));
        if (!"CASH_ONLY".equalsIgnoreCase(paymentProvider)) {
            throw invalid("PAYMENT_PROVIDER must be CASH_ONLY until a real payment provider is implemented");
        }
    }

    private void requireSecret(String name, String value, int minimumLength) {
        String normalized = value == null ? "" : value.trim();
        String lower = normalized.toLowerCase();
        if (normalized.length() < minimumLength || lower.contains("change-this")
                || lower.contains("development") || lower.contains("local-simulated")) {
            throw invalid(name + " must be a strong production secret of at least " + minimumLength + " characters");
        }
    }

    private void requireHttps(String name, String value) {
        try {
            URI uri = URI.create(value);
            if (!"https".equalsIgnoreCase(uri.getScheme()) || uri.getHost() == null) {
                throw invalid(name + " must be an absolute HTTPS URL");
            }
        } catch (IllegalArgumentException exception) {
            throw invalid(name + " must be an absolute HTTPS URL");
        }
    }

    private IllegalStateException invalid(String message) {
        return new IllegalStateException("Invalid production configuration: " + message);
    }
}
