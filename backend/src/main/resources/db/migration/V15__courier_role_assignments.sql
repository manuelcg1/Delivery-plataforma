-- Repara perfiles existentes: un perfil de repartidor siempre debe tener el
-- rol COURIER del mismo tenant.
INSERT INTO user_roles(user_id, role_id)
SELECT cp.user_id, r.id
FROM courier_profiles cp
JOIN roles r ON r.tenant_id = cp.tenant_id
            AND r.code = 'COURIER'
            AND r.active
ON CONFLICT DO NOTHING;

CREATE OR REPLACE FUNCTION assign_courier_role() RETURNS trigger AS $$
BEGIN
  INSERT INTO user_roles(user_id, role_id)
  SELECT NEW.user_id, r.id
  FROM roles r
  WHERE r.tenant_id = NEW.tenant_id
    AND r.code = 'COURIER'
    AND r.active
  ON CONFLICT DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_assign_courier_role
AFTER INSERT ON courier_profiles
FOR EACH ROW EXECUTE FUNCTION assign_courier_role();
