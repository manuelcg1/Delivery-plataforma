ALTER TABLE tenants RENAME COLUMN slug TO code;
ALTER TABLE tenants ADD COLUMN legal_name VARCHAR(160), ADD COLUMN document_type VARCHAR(30),
  ADD COLUMN document_number VARCHAR(60), ADD COLUMN email VARCHAR(254), ADD COLUMN phone VARCHAR(40);
ALTER TABLE users ADD COLUMN phone VARCHAR(40), ADD COLUMN email_verified BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN failed_login_attempts INTEGER NOT NULL DEFAULT 0, ADD COLUMN locked_until TIMESTAMPTZ,
  ADD COLUMN last_login_at TIMESTAMPTZ;

CREATE TABLE permissions (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), code VARCHAR(100) UNIQUE NOT NULL,
 module VARCHAR(60) NOT NULL, action VARCHAR(60) NOT NULL, description VARCHAR(255));
CREATE TABLE roles (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id UUID REFERENCES tenants(id),
 code VARCHAR(80) NOT NULL, name VARCHAR(120) NOT NULL, description VARCHAR(255), system_role BOOLEAN NOT NULL DEFAULT false,
 active BOOLEAN NOT NULL DEFAULT true, created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE UNIQUE INDEX uq_roles_tenant_code ON roles(COALESCE(tenant_id, '00000000-0000-0000-0000-000000000000'::uuid), code);
CREATE TABLE user_roles (user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE, role_id UUID NOT NULL REFERENCES roles(id), PRIMARY KEY(user_id, role_id));
CREATE TABLE role_permissions (role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE, permission_id UUID NOT NULL REFERENCES permissions(id), PRIMARY KEY(role_id, permission_id));
CREATE TABLE refresh_tokens (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), user_id UUID NOT NULL REFERENCES users(id), token_hash VARCHAR(64) UNIQUE NOT NULL,
 expires_at TIMESTAMPTZ NOT NULL, revoked_at TIMESTAMPTZ, created_at TIMESTAMPTZ NOT NULL DEFAULT now(), created_ip VARCHAR(64), user_agent VARCHAR(500));
CREATE TABLE password_reset_tokens (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), user_id UUID NOT NULL REFERENCES users(id), token_hash VARCHAR(64) UNIQUE NOT NULL,
 expires_at TIMESTAMPTZ NOT NULL, used_at TIMESTAMPTZ, created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE TABLE audit_logs (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id UUID REFERENCES tenants(id), user_id UUID REFERENCES users(id),
 action VARCHAR(100) NOT NULL, entity_type VARCHAR(80), entity_id UUID, ip_address VARCHAR(64), user_agent VARCHAR(500), metadata JSONB, created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE INDEX idx_tenants_status ON tenants(status); CREATE INDEX idx_roles_tenant ON roles(tenant_id); CREATE INDEX idx_users_status ON users(status);
CREATE INDEX idx_refresh_user ON refresh_tokens(user_id); CREATE INDEX idx_refresh_expiry ON refresh_tokens(expires_at);
CREATE INDEX idx_reset_expiry ON password_reset_tokens(expires_at); CREATE INDEX idx_audit_tenant_created ON audit_logs(tenant_id, created_at DESC);

INSERT INTO permissions(code,module,action,description) VALUES
('IDENTITY_USERS_VIEW','IDENTITY','USERS_VIEW','Ver usuarios'),('IDENTITY_USERS_CREATE','IDENTITY','USERS_CREATE','Crear usuarios'),
('IDENTITY_USERS_UPDATE','IDENTITY','USERS_UPDATE','Editar usuarios'),('IDENTITY_USERS_DISABLE','IDENTITY','USERS_DISABLE','Cambiar estado'),
('IDENTITY_ROLES_VIEW','IDENTITY','ROLES_VIEW','Ver roles'),('IDENTITY_ROLES_CREATE','IDENTITY','ROLES_CREATE','Crear roles'),
('IDENTITY_ROLES_UPDATE','IDENTITY','ROLES_UPDATE','Editar roles'),('IDENTITY_ROLES_ASSIGN','IDENTITY','ROLES_ASSIGN','Asignar roles'),
('IDENTITY_AUDIT_VIEW','IDENTITY','AUDIT_VIEW','Ver auditoría'),('TENANT_SETTINGS_VIEW','TENANT','SETTINGS_VIEW','Ver empresa'),
('TENANT_SETTINGS_UPDATE','TENANT','SETTINGS_UPDATE','Editar empresa');
INSERT INTO roles(tenant_id,code,name,description,system_role) VALUES(NULL,'PLATFORM_ADMIN','Administrador de plataforma','Rol global',true);
INSERT INTO role_permissions(role_id,permission_id) SELECT r.id,p.id FROM roles r CROSS JOIN permissions p WHERE r.code='PLATFORM_ADMIN' AND r.tenant_id IS NULL;
