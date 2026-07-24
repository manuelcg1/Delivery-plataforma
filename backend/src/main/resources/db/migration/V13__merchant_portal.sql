ALTER TABLE orders ADD COLUMN version INTEGER NOT NULL DEFAULT 0;
ALTER TABLE orders ADD COLUMN accepted_at TIMESTAMPTZ;
ALTER TABLE orders ADD COLUMN ready_at TIMESTAMPTZ;
ALTER TABLE orders ADD COLUMN rejection_reason VARCHAR(500);

ALTER TABLE branches ADD COLUMN paused_until TIMESTAMPTZ;
ALTER TABLE branches ADD COLUMN pause_reason VARCHAR(255);

CREATE TABLE merchant_memberships (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
 tenant_id UUID NOT NULL REFERENCES tenants(id),
 merchant_id UUID NOT NULL REFERENCES merchants(id) ON DELETE CASCADE,
 user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 role_code VARCHAR(40) NOT NULL DEFAULT 'OPERATOR',
 active BOOLEAN NOT NULL DEFAULT true,
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 UNIQUE(merchant_id,user_id),
 CHECK(role_code IN ('OWNER','MANAGER','OPERATOR','CATALOG','FINANCE','VIEWER'))
);
CREATE INDEX idx_merchant_memberships_user ON merchant_memberships(tenant_id,user_id,active);

CREATE TABLE merchant_branch_assignments (
 tenant_id UUID NOT NULL REFERENCES tenants(id),
 membership_id UUID NOT NULL REFERENCES merchant_memberships(id) ON DELETE CASCADE,
 branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
 PRIMARY KEY(membership_id,branch_id)
);

CREATE TABLE merchant_incidents (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id UUID NOT NULL REFERENCES tenants(id),
 merchant_id UUID NOT NULL REFERENCES merchants(id), branch_id UUID REFERENCES branches(id), order_id UUID REFERENCES orders(id),
 created_by UUID NOT NULL REFERENCES users(id), type VARCHAR(40) NOT NULL, priority VARCHAR(20) NOT NULL DEFAULT 'MEDIUM',
 status VARCHAR(20) NOT NULL DEFAULT 'OPEN', title VARCHAR(160) NOT NULL, description TEXT NOT NULL,
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 CHECK(priority IN ('LOW','MEDIUM','HIGH','CRITICAL')), CHECK(status IN ('OPEN','IN_PROGRESS','RESOLVED','CLOSED'))
);
CREATE INDEX idx_merchant_incidents_scope ON merchant_incidents(tenant_id,merchant_id,status,created_at DESC);

INSERT INTO permissions(code,module,action,description) VALUES
 ('MERCHANT_PORTAL_ACCESS','MERCHANT','ACCESS','Acceder al portal de comercios'),
 ('MERCHANT_ORDERS_VIEW','MERCHANT','ORDERS_VIEW','Ver pedidos del comercio asignado'),
 ('MERCHANT_ORDERS_MANAGE','MERCHANT','ORDERS_MANAGE','Gestionar pedidos del comercio asignado'),
 ('MERCHANT_BRANCH_OPERATE','MERCHANT','BRANCH_OPERATE','Operar sucursales asignadas'),
 ('MERCHANT_REPORTS_VIEW','MERCHANT','REPORTS_VIEW','Ver reportes del comercio asignado'),
 ('MERCHANT_INCIDENTS_MANAGE','MERCHANT','INCIDENTS_MANAGE','Gestionar incidencias del comercio asignado')
ON CONFLICT(code) DO NOTHING;

INSERT INTO role_permissions(role_id,permission_id)
SELECT r.id,p.id FROM roles r CROSS JOIN permissions p
WHERE r.code IN ('TENANT_ADMIN','PLATFORM_ADMIN') AND p.module='MERCHANT'
ON CONFLICT DO NOTHING;

INSERT INTO role_permissions(role_id,permission_id)
SELECT r.id,p.id FROM roles r CROSS JOIN permissions p
WHERE r.code='MERCHANT_OPERATOR' AND p.code IN
 ('MERCHANT_PORTAL_ACCESS','MERCHANT_ORDERS_VIEW','MERCHANT_ORDERS_MANAGE','MERCHANT_BRANCH_OPERATE','MERCHANT_INCIDENTS_MANAGE')
ON CONFLICT DO NOTHING;

-- Existing merchant operators receive an explicit, auditable scope. Tenant admins
-- remain tenant-wide and therefore do not need membership rows.
INSERT INTO merchant_memberships(tenant_id,merchant_id,user_id,role_code)
SELECT r.tenant_id,m.id,ur.user_id,'OPERATOR'
FROM user_roles ur JOIN roles r ON r.id=ur.role_id AND r.code='MERCHANT_OPERATOR'
JOIN merchants m ON m.tenant_id=r.tenant_id
ON CONFLICT(merchant_id,user_id) DO NOTHING;

INSERT INTO merchant_branch_assignments(tenant_id,membership_id,branch_id)
SELECT mm.tenant_id,mm.id,b.id FROM merchant_memberships mm
JOIN branches b ON b.tenant_id=mm.tenant_id AND b.merchant_id=mm.merchant_id
ON CONFLICT DO NOTHING;
