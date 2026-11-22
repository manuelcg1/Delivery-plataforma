package com.delivery.platform.legal;

import com.delivery.platform.common.ApiException;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class LegalDocumentsTest {
    @Test
    void bothDocumentsAreBundledWithTheCurrentVersion() {
        for (LegalDocuments.Type type : LegalDocuments.Type.values()) {
            LegalDocuments.Document document = LegalDocuments.load(type);
            assertThat(document.version()).isEqualTo(LegalDocuments.CURRENT_VERSION);
            assertThat(document.content()).startsWith("# ").contains("Versión " + LegalDocuments.CURRENT_VERSION);
        }
    }

    @Test
    void privacyPolicyCitesPeruvianDataProtectionRules() {
        String privacy = LegalDocuments.load(LegalDocuments.Type.PRIVACY).content();
        assertThat(privacy).contains("Ley N.º 29733", "016-2024-JUS", "ARCO", "Autoridad Nacional de Protección de Datos Personales");
    }

    @Test
    void termsExplainTheDeliveryCodeRule() {
        assertThat(LegalDocuments.load(LegalDocuments.Type.TERMS).content())
                .contains("no compartas tu código de entrega hasta que tu pedido haya llegado", "Ley N.º 29571");
    }

    @Test
    void registrationRequiresTheCurrentVersion() {
        LegalDocuments.requireCurrent(LegalDocuments.CURRENT_VERSION);
        assertThatThrownBy(() -> LegalDocuments.requireCurrent("2020-01-01")).isInstanceOf(ApiException.class);
        assertThatThrownBy(() -> LegalDocuments.requireCurrent(null)).isInstanceOf(ApiException.class);
    }

    @Test
    void unknownDocumentIsNotFound() {
        assertThatThrownBy(() -> LegalDocuments.Type.fromSlug("../secret")).isInstanceOf(ApiException.class);
    }
}
