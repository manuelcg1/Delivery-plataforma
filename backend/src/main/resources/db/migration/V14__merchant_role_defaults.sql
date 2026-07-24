CREATE OR REPLACE FUNCTION seed_merchant_portal_role_permissions() RETURNS trigger AS $$
BEGIN
 IF NEW.code = 'MERCHANT_OPERATOR' THEN
  INSERT INTO role_permissions(role_id,permission_id)
  SELECT NEW.id,p.id FROM permissions p WHERE p.code IN (
   'MERCHANT_PORTAL_ACCESS','MERCHANT_ORDERS_VIEW','MERCHANT_ORDERS_MANAGE',
   'MERCHANT_BRANCH_OPERATE','MERCHANT_INCIDENTS_MANAGE'
  ) ON CONFLICT DO NOTHING;
 ELSIF NEW.code IN ('TENANT_ADMIN','PLATFORM_ADMIN') THEN
  INSERT INTO role_permissions(role_id,permission_id)
  SELECT NEW.id,p.id FROM permissions p WHERE p.module='MERCHANT'
  ON CONFLICT DO NOTHING;
 END IF;
 RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_seed_merchant_portal_role_permissions
AFTER INSERT ON roles
FOR EACH ROW EXECUTE FUNCTION seed_merchant_portal_role_permissions();
