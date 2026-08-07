ALTER TABLE deliveries DROP CONSTRAINT deliveries_arrival_method_check;
UPDATE deliveries SET arrival_method='AUTOMATIC' WHERE arrival_method='GEOFENCE';
ALTER TABLE deliveries ADD CONSTRAINT deliveries_arrival_method_check
  CHECK (arrival_method IS NULL OR arrival_method IN ('AUTOMATIC','MANUAL'));

CREATE TABLE courier_arrival_audit (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES tenants(id),
  delivery_id UUID NOT NULL REFERENCES deliveries(id),
  order_id UUID NOT NULL REFERENCES orders(id),
  courier_id UUID NOT NULL REFERENCES courier_profiles(id),
  latitude NUMERIC(10,7), longitude NUMERIC(10,7),
  distance_meters NUMERIC(10,2), accuracy_meters NUMERIC(10,2),
  arrival_method VARCHAR(20) NOT NULL CHECK (arrival_method IN ('AUTOMATIC','MANUAL')),
  detected_at TIMESTAMPTZ NOT NULL,
  notified_at TIMESTAMPTZ,
  UNIQUE (tenant_id, delivery_id)
);

CREATE OR REPLACE FUNCTION reject_courier_arrival_audit_mutation() RETURNS trigger AS $$
BEGIN
  IF TG_OP = 'UPDATE' AND OLD.notified_at IS NULL AND NEW.notified_at IS NOT NULL
     AND (to_jsonb(NEW) - 'notified_at') = (to_jsonb(OLD) - 'notified_at') THEN
    RETURN NEW;
  END IF;
  RAISE EXCEPTION 'courier_arrival_audit is immutable';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER courier_arrival_audit_immutable
BEFORE UPDATE OR DELETE ON courier_arrival_audit
FOR EACH ROW EXECUTE FUNCTION reject_courier_arrival_audit_mutation();
