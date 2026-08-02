CREATE TABLE device_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES tenants(id),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  courier_id UUID REFERENCES courier_profiles(id) ON DELETE CASCADE,
  token TEXT NOT NULL,
  platform VARCHAR(20) NOT NULL,
  active BOOLEAN NOT NULL DEFAULT true,
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT device_tokens_platform CHECK (platform IN ('ANDROID','IOS')),
  UNIQUE (tenant_id, token)
);
CREATE INDEX idx_device_tokens_user_active ON device_tokens(tenant_id,user_id) WHERE active;

ALTER TABLE notifications ADD COLUMN IF NOT EXISTS deduplication_key VARCHAR(160);
CREATE UNIQUE INDEX uq_notifications_deduplication
  ON notifications(tenant_id,user_id,deduplication_key)
  WHERE deduplication_key IS NOT NULL;
