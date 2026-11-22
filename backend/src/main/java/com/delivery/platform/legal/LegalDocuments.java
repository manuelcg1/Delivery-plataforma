package com.delivery.platform.legal;

import com.delivery.platform.common.ApiException;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.Map;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;

/** Términos y Condiciones y Política de Privacidad vigentes. Fuente única para apps y portales. */
public final class LegalDocuments {
    private LegalDocuments() {}

    /** Cambiar esta versión obliga a que los nuevos registros acepten el texto actualizado. */
    public static final String CURRENT_VERSION = "2026-11-21";

    public enum Type {
        TERMS("terminos-y-condiciones", "Términos y Condiciones"),
        PRIVACY("politica-de-privacidad", "Política de Privacidad");

        public final String slug;
        public final String title;

        Type(String slug, String title) {
            this.slug = slug;
            this.title = title;
        }

        public static Type fromSlug(String slug) {
            for (Type type : values()) if (type.slug.equals(slug)) return type;
            throw new ApiException(HttpStatus.NOT_FOUND, "LEGAL_DOCUMENT_NOT_FOUND", "Documento no encontrado");
        }
    }

    public record Document(String slug, String title, String version, String content) {}

    public static Document load(Type type) {
        try (InputStream in = LegalDocuments.class.getResourceAsStream("/legal/" + type.slug + ".md")) {
            if (in == null) throw new IllegalStateException("Falta el documento legal " + type.slug);
            return new Document(type.slug, type.title, CURRENT_VERSION, new String(in.readAllBytes(), StandardCharsets.UTF_8));
        } catch (IOException e) {
            throw new IllegalStateException("No se pudo leer el documento legal " + type.slug, e);
        }
    }

    public static void requireCurrent(String acceptedVersion) {
        if (!CURRENT_VERSION.equals(acceptedVersion))
            throw new ApiException(HttpStatus.BAD_REQUEST, "LEGAL_ACCEPTANCE_REQUIRED",
                    "Acepta los Términos y Condiciones y la Política de Privacidad vigentes para crear tu cuenta");
    }

    /** Registra la aceptación de ambos documentos (prueba del consentimiento). */
    public static void recordAcceptance(JdbcClient db, UUID tenant, UUID user, String ip, String agent) {
        for (Type type : Type.values()) {
            db.sql("insert into legal_acceptances(tenant_id,user_id,document_type,document_version,ip_address,user_agent) values(:t,:u,:d,:v,:ip,:ua)")
                    .param("t", tenant).param("u", user).param("d", type.name()).param("v", CURRENT_VERSION)
                    .param("ip", ip).param("ua", agent == null ? null : agent.substring(0, Math.min(agent.length(), 500)))
                    .update();
        }
    }

    public static Map<String, String> summary() {
        return Map.of("version", CURRENT_VERSION,
                "terms", "/api/v1/public/legal/" + Type.TERMS.slug,
                "privacy", "/api/v1/public/legal/" + Type.PRIVACY.slug);
    }
}
