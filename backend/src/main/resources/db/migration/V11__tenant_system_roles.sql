-- Roles funcionales estándar para todos los tenants existentes.
INSERT INTO roles(tenant_id, code, name, description, system_role, active)
SELECT t.id, seed.code, seed.name, seed.description, true, true
FROM tenants t
CROSS JOIN (VALUES
 ('CUSTOMER','Cliente','Compra, paga y realiza seguimiento de sus propios pedidos'),
 ('COURIER','Repartidor','Gestiona disponibilidad, entregas asignadas, ubicación y pruebas'),
 ('MERCHANT_OPERATOR','Operador de comercio','Gestiona catálogo y operación comercial del tenant'),
 ('DISPATCHER','Despachador','Coordina entregas, repartidores, tracking y zonas'),
 ('TENANT_ADMIN','Administrador del tenant','Administración completa del tenant')
) AS seed(code,name,description)
ON CONFLICT DO NOTHING;

-- CUSTOMER: autoservicio de compra y seguimiento propio.
INSERT INTO role_permissions(role_id, permission_id)
SELECT r.id, p.id FROM roles r JOIN permissions p ON p.code IN (
 'ORDERS_CART_VIEW','ORDERS_CART_MANAGE','ORDERS_CREATE','ORDERS_VIEW',
 'PAYMENT_VIEW','PAYMENT_CREATE','DELIVERY_VIEW','DELIVERY_CREATE',
 'TRACKING_VIEW','PROOF_VIEW','CHAT_VIEW','CHAT_SEND','NOTIFICATION_VIEW'
) WHERE r.tenant_id IS NOT NULL AND r.code='CUSTOMER'
ON CONFLICT DO NOTHING;

-- COURIER: únicamente operación propia y entregas asignadas.
INSERT INTO role_permissions(role_id, permission_id)
SELECT r.id, p.id FROM roles r JOIN permissions p ON p.code IN (
 'DELIVERY_VIEW','DELIVERY_UPDATE_STATUS','COURIER_VIEW','COURIER_AVAILABILITY_MANAGE',
 'COURIER_LOCATION_UPDATE','TRACKING_VIEW','PROOF_VIEW','PROOF_CREATE',
 'CHAT_VIEW','CHAT_SEND','NOTIFICATION_VIEW'
) WHERE r.tenant_id IS NOT NULL AND r.code='COURIER'
ON CONFLICT DO NOTHING;

-- MERCHANT_OPERATOR: catálogo y operación del comercio dentro del tenant.
INSERT INTO role_permissions(role_id, permission_id)
SELECT r.id, p.id FROM roles r JOIN permissions p ON (
 p.module='CATALOG' OR p.code IN (
  'ORDERS_VIEW','ORDERS_STATUS_UPDATE','PAYMENT_VIEW','DELIVERY_VIEW',
  'TRACKING_VIEW','CHAT_VIEW','CHAT_SEND','NOTIFICATION_VIEW'
 )
) WHERE r.tenant_id IS NOT NULL AND r.code='MERCHANT_OPERATOR'
ON CONFLICT DO NOTHING;

-- DISPATCHER: coordinación logística completa, sin administración de identidad ni catálogo.
INSERT INTO role_permissions(role_id, permission_id)
SELECT r.id, p.id FROM roles r JOIN permissions p ON (
 p.module='DELIVERY' OR p.code IN (
  'ORDERS_VIEW','TRACKING_VIEW','TRACKING_ADMIN','CHAT_VIEW','CHAT_SEND',
  'PROOF_VIEW','NOTIFICATION_VIEW'
 )
) WHERE r.tenant_id IS NOT NULL AND r.code='DISPATCHER'
ON CONFLICT DO NOTHING;

-- TENANT_ADMIN siempre conserva todos los permisos disponibles.
INSERT INTO role_permissions(role_id, permission_id)
SELECT r.id, p.id FROM roles r CROSS JOIN permissions p
WHERE r.tenant_id IS NOT NULL AND r.code='TENANT_ADMIN'
ON CONFLICT DO NOTHING;

-- Los nuevos tenants reciben automáticamente los roles funcionales. TENANT_ADMIN
-- continúa creándose en AuthService para poder asignarlo al usuario fundador.
CREATE OR REPLACE FUNCTION seed_tenant_system_roles() RETURNS trigger AS $$
BEGIN
 INSERT INTO roles(tenant_id,code,name,description,system_role,active) VALUES
  (NEW.id,'CUSTOMER','Cliente','Compra, paga y realiza seguimiento de sus propios pedidos',true,true),
  (NEW.id,'COURIER','Repartidor','Gestiona disponibilidad, entregas asignadas, ubicación y pruebas',true,true),
  (NEW.id,'MERCHANT_OPERATOR','Operador de comercio','Gestiona catálogo y operación comercial del tenant',true,true),
  (NEW.id,'DISPATCHER','Despachador','Coordina entregas, repartidores, tracking y zonas',true,true);

 INSERT INTO role_permissions(role_id,permission_id)
 SELECT r.id,p.id FROM roles r JOIN permissions p ON
  (r.code='CUSTOMER' AND p.code IN ('ORDERS_CART_VIEW','ORDERS_CART_MANAGE','ORDERS_CREATE','ORDERS_VIEW','PAYMENT_VIEW','PAYMENT_CREATE','DELIVERY_VIEW','DELIVERY_CREATE','TRACKING_VIEW','PROOF_VIEW','CHAT_VIEW','CHAT_SEND','NOTIFICATION_VIEW')) OR
  (r.code='COURIER' AND p.code IN ('DELIVERY_VIEW','DELIVERY_UPDATE_STATUS','COURIER_VIEW','COURIER_AVAILABILITY_MANAGE','COURIER_LOCATION_UPDATE','TRACKING_VIEW','PROOF_VIEW','PROOF_CREATE','CHAT_VIEW','CHAT_SEND','NOTIFICATION_VIEW')) OR
  (r.code='MERCHANT_OPERATOR' AND (p.module='CATALOG' OR p.code IN ('ORDERS_VIEW','ORDERS_STATUS_UPDATE','PAYMENT_VIEW','DELIVERY_VIEW','TRACKING_VIEW','CHAT_VIEW','CHAT_SEND','NOTIFICATION_VIEW'))) OR
  (r.code='DISPATCHER' AND (p.module='DELIVERY' OR p.code IN ('ORDERS_VIEW','TRACKING_VIEW','TRACKING_ADMIN','CHAT_VIEW','CHAT_SEND','PROOF_VIEW','NOTIFICATION_VIEW')))
 WHERE r.tenant_id=NEW.id
 ON CONFLICT DO NOTHING;
 RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_seed_tenant_system_roles
AFTER INSERT ON tenants
FOR EACH ROW EXECUTE FUNCTION seed_tenant_system_roles();
