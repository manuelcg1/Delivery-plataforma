CREATE TABLE merchant_yape_settings (
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    merchant_id UUID NOT NULL REFERENCES merchants(id),
    enabled BOOLEAN NOT NULL DEFAULT false,
    phone VARCHAR(9),
    holder_name VARCHAR(160),
    qr_object_key VARCHAR(500),
    version VARCHAR(36) NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id,merchant_id),
    CHECK (phone IS NULL OR phone ~ '^9[0-9]{8}$'),
    CHECK (NOT enabled OR (phone IS NOT NULL AND holder_name IS NOT NULL AND length(trim(holder_name))>0 AND qr_object_key IS NOT NULL))
);
ALTER TABLE payments ADD COLUMN yape_settings_version VARCHAR(36);
ALTER TABLE payments ADD COLUMN yape_receiver_phone VARCHAR(9);
ALTER TABLE payments ADD COLUMN yape_receiver_holder VARCHAR(160);
ALTER TABLE payments ADD COLUMN customer_declared_at TIMESTAMPTZ;
