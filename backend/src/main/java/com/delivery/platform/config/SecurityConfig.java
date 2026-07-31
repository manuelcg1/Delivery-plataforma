package com.delivery.platform.config;

import com.delivery.platform.identity.security.JwtFilter;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.*;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.*;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.*;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.*;
import java.util.*;

@Configuration
@EnableMethodSecurity
public class SecurityConfig {
    @Bean
    PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    @Bean
    SecurityFilterChain chain(org.springframework.security.config.annotation.web.builders.HttpSecurity h, JwtFilter f,
            CorsConfigurationSource cors)
            throws Exception {
        return h.csrf(x -> x.disable()).cors(x -> x.configurationSource(cors))
                .sessionManagement(x -> x.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .exceptionHandling(x -> x.authenticationEntryPoint((request, response, exception) ->
                        response.sendError(HttpStatus.UNAUTHORIZED.value(), "Unauthorized")))
                .authorizeHttpRequests(x -> x
                        .requestMatchers("/api/v1/public/**", "/actuator/health", "/actuator/health/**")
                        .permitAll()
                        .requestMatchers("/swagger-ui/**", "/swagger-ui.html", "/v3/api-docs/**")
                        .hasAuthority("PLATFORM_MANAGE")
                        .requestMatchers(HttpMethod.POST, "/api/v1/auth/register-tenant",
                                "/api/v1/auth/register-customer", "/api/v1/auth/login", "/api/v1/auth/login-mobile",
                                "/api/v1/auth/refresh", "/api/v1/auth/refresh-mobile", "/api/v1/auth/forgot-password",
                                "/api/v1/auth/reset-password", "/api/v1/webhooks/payments/**")
                        .permitAll().anyRequest().authenticated())
                .addFilterBefore(f, UsernamePasswordAuthenticationFilter.class).build();
    }

    @Bean
    CorsConfigurationSource cors(
            @Value("${CORS_ALLOWED_ORIGINS:http://localhost:3000,http://localhost:3001}") String origins) {
        var c = new CorsConfiguration();
        c.setAllowedOrigins(Arrays.stream(origins.split(",")).map(String::trim).toList());
        c.setAllowedMethods(List.of("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"));
        c.setAllowedHeaders(List.of("*"));
        c.setAllowCredentials(true);
        var s = new UrlBasedCorsConfigurationSource();
        s.registerCorsConfiguration("/**", c);
        return s;
    }
}
