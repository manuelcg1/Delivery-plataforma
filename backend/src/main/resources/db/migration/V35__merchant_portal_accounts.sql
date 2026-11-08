-- A dedicated role avoids exposing tenant-wide catalog APIs to new merchant accounts.
CREATE OR REPLACE FUNCTION seed_merchant_portal_role_permissions() RETURNS trigger AS $$
BEGIN
 IF NEW.code IN ('MERCHANT_OPERATOR','MERCHANT_PORTAL_OPERATOR') THEN
  INSERT INTO role_permissions(role_id,permission_id)
  SELECT NEW.id,p.id FROM permissions p WHERE p.code IN (
   'MERCHANT_PORTAL_ACCESS','MERCHANT_ORDERS_VIEW','MERCHANT_ORDERS_MANAGE',
   'MERCHANT_BRANCH_OPERATE','MERCHANT_INCIDENTS_MANAGE',
   'MERCHANT_ORDER_VIEW','MERCHANT_DELIVERY_ASSIGN','MERCHANT_DELIVERY_VIEW_COURIERS','MERCHANT_ORDER_HAND_TO_COURIER'
  ) ON CONFLICT DO NOTHING;
 ELSIF NEW.code IN ('TENANT_ADMIN','PLATFORM_ADMIN') THEN
  INSERT INTO role_permissions(role_id,permission_id)
  SELECT NEW.id,p.id FROM permissions p WHERE p.module='MERCHANT'
  ON CONFLICT DO NOTHING;
 END IF;
 RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Backfill only the delivery capabilities previously introduced by V18.
INSERT INTO role_permissions(role_id,permission_id)
SELECT r.id,p.id FROM roles r CROSS JOIN permissions p
WHERE r.code='MERCHANT_OPERATOR' AND r.tenant_id IS NOT NULL AND p.code IN (
 'MERCHANT_ORDER_VIEW','MERCHANT_DELIVERY_ASSIGN','MERCHANT_DELIVERY_VIEW_COURIERS','MERCHANT_ORDER_HAND_TO_COURIER')
ON CONFLICT DO NOTHING;

INSERT INTO roles(tenant_id,code,name,description,system_role)
SELECT id,'MERCHANT_PORTAL_OPERATOR','Operador del portal de comercio',
 'Pedidos y reparto únicamente de los comercios y sucursales asignados',true
FROM tenants
ON CONFLICT DO NOTHING;

CREATE FUNCTION seed_scoped_merchant_role() RETURNS trigger AS $$
BEGIN
 INSERT INTO roles(tenant_id,code,name,description,system_role)
 VALUES(NEW.id,'MERCHANT_PORTAL_OPERATOR','Operador del portal de comercio',
        'Pedidos y reparto únicamente de los comercios y sucursales asignados',true)
 ON CONFLICT DO NOTHING;
 RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_seed_scoped_merchant_role AFTER INSERT ON tenants
 FOR EACH ROW EXECUTE FUNCTION seed_scoped_merchant_role();

-- Only full merchant owners receive future branches; restricted staff keep their assignments.
CREATE FUNCTION assign_new_branch_to_merchant_owners() RETURNS trigger AS $$
BEGIN
 INSERT INTO merchant_branch_assignments(tenant_id,membership_id,branch_id)
 SELECT NEW.tenant_id,m.id,NEW.id FROM merchant_memberships m
 WHERE m.tenant_id=NEW.tenant_id AND m.merchant_id=NEW.merchant_id AND m.role_code='OWNER' AND m.active
 ON CONFLICT DO NOTHING;
 RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_assign_new_merchant_branch AFTER INSERT ON branches
 FOR EACH ROW EXECUTE FUNCTION assign_new_branch_to_merchant_owners();
