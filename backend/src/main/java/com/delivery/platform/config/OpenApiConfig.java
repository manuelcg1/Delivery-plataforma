package com.delivery.platform.config;

import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Contact;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.security.SecurityRequirement;
import io.swagger.v3.oas.models.security.SecurityScheme;
import io.swagger.v3.oas.models.tags.Tag;
import java.util.List;
import org.springdoc.core.models.GroupedOpenApi;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class OpenApiConfig {
    @Bean OpenAPI deliveryPlatformOpenApi() {
        String bearer = "bearerAuth";
        return new OpenAPI()
                .info(new Info().title("Delivery Platform API").version("0.3")
                        .description("API multi-tenant de identidad, comercios, catálogo, precios, horarios, inventario e imágenes. Los permisos requeridos aparecen en la operación y se validan con Spring Security.")
                        .contact(new Contact().name("Delivery Platform")))
                .components(new Components().addSecuritySchemes(bearer,
                        new SecurityScheme().type(SecurityScheme.Type.HTTP).scheme("bearer").bearerFormat("JWT")))
                .security(List.of(new SecurityRequirement().addList(bearer)))
                .tags(List.of(
                        new Tag().name("Catálogo público").description("Lectura pública cacheada; no requiere JWT"),
                        new Tag().name("Comercios").description("Administración de comercios aislada por tenant"),
                        new Tag().name("Productos").description("Productos, variantes, opciones y publicación"),
                        new Tag().name("Precios").description("Listas y resolución de precios vigentes"),
                        new Tag().name("Horarios").description("Horarios semanales, especiales y disponibilidad"),
                        new Tag().name("Imágenes").description("Carga MinIO, orden, portada y URLs firmadas")));
    }

    @Bean GroupedOpenApi catalogApi() {
        return GroupedOpenApi.builder().group("catalog-v0.3").pathsToMatch("/api/v1/**catalog/**", "/api/v1/merchants/**",
                "/api/v1/branches/**", "/api/v1/products/**", "/api/v1/categories/**",
                "/api/v1/option-groups/**", "/api/v1/price-lists/**", "/api/v1/inventory/**").build();
    }
}
