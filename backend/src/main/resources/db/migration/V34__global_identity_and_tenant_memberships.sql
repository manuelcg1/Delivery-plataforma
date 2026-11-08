CREATE TABLE identity_accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(254),
  legacy_email VARCHAR(254),
  password_hash VARCHAR(100) NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
  last_tenant_id UUID REFERENCES tenants(id),
  failed_login_attempts INTEGER NOT NULL DEFAULT 0,
  locked_until TIMESTAMPTZ,
  email_conflict BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (status IN ('ACTIVE','INACTIVE','LOCKED'))
);

CREATE UNIQUE INDEX uq_identity_accounts_email_ci
  ON identity_accounts(lower(email)) WHERE email IS NOT NULL;
CREATE INDEX idx_identity_accounts_legacy_email
  ON identity_accounts(lower(legacy_email));

ALTER TABLE users ADD COLUMN identity_id UUID;

INSERT INTO identity_accounts(id,email,legacy_email,password_hash,status,last_tenant_id,failed_login_attempts,locked_until,email_conflict)
SELECT u.id,
       CASE WHEN count(*) OVER (PARTITION BY lower(u.email)) = 1 THEN lower(u.email) ELSE NULL END,
      lower(u.email),u.password_hash,
       CASE WHEN u.status='LOCKED' THEN 'LOCKED' WHEN u.status='INACTIVE' THEN 'INACTIVE' ELSE 'ACTIVE' END,
      u.tenant_id,u.failed_login_attempts,u.locked_until,
       count(*) OVER (PARTITION BY lower(u.email)) > 1
FROM users u;

UPDATE users SET identity_id=id;

ALTER TABLE users ALTER COLUMN identity_id SET NOT NULL;
ALTER TABLE users ADD CONSTRAINT fk_users_identity_account
  FOREIGN KEY (identity_id) REFERENCES identity_accounts(id);

CREATE TABLE tenant_memberships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  identity_id UUID NOT NULL REFERENCES identity_accounts(id) ON DELETE CASCADE,
  tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(identity_id,tenant_id)
);

INSERT INTO tenant_memberships(identity_id,tenant_id,user_id,active)
-- A timed authentication lock must not become a permanent membership suspension.
SELECT u.identity_id,u.tenant_id,u.id,
       u.status='ACTIVE' OR (u.status='LOCKED' AND u.locked_until IS NOT NULL)
FROM users u;

ALTER TABLE refresh_tokens ADD COLUMN context_tenant_id UUID REFERENCES tenants(id);
UPDATE refresh_tokens rt SET context_tenant_id=u.tenant_id
FROM users u WHERE u.id=rt.user_id;
ALTER TABLE refresh_tokens ALTER COLUMN context_tenant_id SET NOT NULL;

CREATE INDEX idx_tenant_memberships_identity ON tenant_memberships(identity_id,active,tenant_id);
