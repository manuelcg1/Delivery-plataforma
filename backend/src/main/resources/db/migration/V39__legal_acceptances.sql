-- Prueba del consentimiento: qué versión de los Términos y de la Política de
-- Privacidad aceptó cada usuario, cuándo y desde dónde.
CREATE TABLE legal_acceptances (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    user_id UUID NOT NULL REFERENCES users(id),
    document_type VARCHAR(20) NOT NULL,
    document_version VARCHAR(20) NOT NULL,
    accepted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    ip_address VARCHAR(64),
    user_agent VARCHAR(500),
    CHECK (document_type IN ('TERMS','PRIVACY')),
    UNIQUE (tenant_id, user_id, document_type, document_version)
);
CREATE INDEX idx_legal_acceptances_user ON legal_acceptances(tenant_id, user_id);
