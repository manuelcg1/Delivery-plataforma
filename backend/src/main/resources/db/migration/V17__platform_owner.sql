ALTER TABLE users
  ADD COLUMN IF NOT EXISTS username VARCHAR(80),
  ADD COLUMN IF NOT EXISTS must_change_password BOOLEAN NOT NULL DEFAULT false;

CREATE UNIQUE INDEX IF NOT EXISTS uq_users_username
  ON users(lower(username)) WHERE username IS NOT NULL;

INSERT INTO permissions(code,module,action,description) VALUES
 ('PLATFORM_MANAGE','PLATFORM','MANAGE','Administración global de la plataforma'),
 ('USER_MANAGE','PLATFORM','USER_MANAGE','Administrar usuarios globalmente'),
 ('TENANT_MANAGE','PLATFORM','TENANT_MANAGE','Administrar todos los tenants'),
 ('MERCHANT_MANAGE','PLATFORM','MERCHANT_MANAGE','Administrar todos los comercios'),
 ('BRANCH_MANAGE','PLATFORM','BRANCH_MANAGE','Administrar todas las sucursales'),
 ('CUSTOMER_VIEW','PLATFORM','CUSTOMER_VIEW','Ver todos los clientes'),
 ('ORDER_VIEW_ALL','PLATFORM','ORDER_VIEW_ALL','Ver todos los pedidos'),
 ('ORDER_UPDATE_ALL','PLATFORM','ORDER_UPDATE_ALL','Actualizar todos los pedidos'),
 ('PAYMENT_VIEW_ALL','PLATFORM','PAYMENT_VIEW_ALL','Ver todos los pagos'),
 ('REPORT_VIEW_GLOBAL','PLATFORM','REPORT_VIEW_GLOBAL','Ver reportes globales'),
 ('SETTINGS_GLOBAL','PLATFORM','SETTINGS_GLOBAL','Ver configuración global'),
 ('ROLE_MANAGE','PLATFORM','ROLE_MANAGE','Administrar roles globales'),
 ('PERMISSION_MANAGE','PLATFORM','PERMISSION_MANAGE','Administrar permisos'),
 ('SYSTEM_AUDIT','PLATFORM','SYSTEM_AUDIT','Ver auditoría global'),
 ('SYSTEM_CONFIGURATION','PLATFORM','SYSTEM_CONFIGURATION','Configurar el sistema'),
 ('INCIDENT_MANAGE','PLATFORM','INCIDENT_MANAGE','Administrar incidencias'),
 ('DELIVERY_MANAGE','PLATFORM','DELIVERY_MANAGE','Administrar entregas globales'),
 ('PROMOTION_MANAGE','PLATFORM','PROMOTION_MANAGE','Administrar promociones'),
 ('NOTIFICATION_MANAGE','PLATFORM','NOTIFICATION_MANAGE','Administrar notificaciones'),
 ('CONFIGURATION_GLOBAL','PLATFORM','CONFIGURATION_GLOBAL','Modificar configuración global'),
 ('INTEGRATION_MANAGE','PLATFORM','INTEGRATION_MANAGE','Administrar integraciones')
ON CONFLICT(code) DO NOTHING;

INSERT INTO tenants(code,name,legal_name,status,email)
VALUES('platform','Platform','Platform','ACTIVE',NULL)
ON CONFLICT(code) DO NOTHING;

INSERT INTO roles(tenant_id,code,name,description,system_role,active)
VALUES(NULL,'ROLE_PLATFORM_OWNER','Platform Owner',
       'Propietario global con administración completa',true,true)
ON CONFLICT DO NOTHING;

INSERT INTO role_permissions(role_id,permission_id)
SELECT r.id,p.id FROM roles r CROSS JOIN permissions p
WHERE r.tenant_id IS NULL AND r.code='ROLE_PLATFORM_OWNER'
ON CONFLICT DO NOTHING;

CREATE OR REPLACE FUNCTION grant_platform_owner_new_permission()
RETURNS trigger AS $$
BEGIN
  INSERT INTO role_permissions(role_id,permission_id)
  SELECT r.id,NEW.id FROM roles r
  WHERE r.tenant_id IS NULL AND r.code='ROLE_PLATFORM_OWNER'
  ON CONFLICT DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_grant_platform_owner_new_permission
AFTER INSERT ON permissions
FOR EACH ROW EXECUTE FUNCTION grant_platform_owner_new_permission();

CREATE TABLE platform_settings(
  setting_key VARCHAR(100) PRIMARY KEY,
  setting_value TEXT NOT NULL,
  category VARCHAR(60) NOT NULL,
  description VARCHAR(255),
  sensitive BOOLEAN NOT NULL DEFAULT false,
  updated_by UUID REFERENCES users(id),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO platform_settings(setting_key,setting_value,category,description) VALUES
 ('commission.default.percent','10.00','COMMISSIONS','Comisión global predeterminada'),
 ('delivery.base.fee','5.00','RATES','Tarifa base global'),
 ('general.default.currency','PEN','GENERAL','Moneda predeterminada'),
 ('security.jwt.access.minutes','15','SECURITY','Duración del access token'),
 ('websocket.global.enabled','true','WEBSOCKET','WebSocket global'),
 ('maps.provider','OPENSTREETMAP','MAPS','Proveedor global de mapas'),
 ('payments.methods.enabled','CARD,CASH','PAYMENTS','Métodos de pago habilitados'),
 ('notifications.global.enabled','true','NOTIFICATIONS','Notificaciones globales'),
 ('integrations.payment.provider','SIMULATED','INTEGRATIONS','Proveedor de pagos predeterminado')
ON CONFLICT(setting_key) DO NOTHING;
