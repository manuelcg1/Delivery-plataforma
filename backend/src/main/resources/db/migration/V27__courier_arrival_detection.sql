ALTER TABLE deliveries
  ADD COLUMN arrival_detected_at TIMESTAMPTZ,
  ADD COLUMN arrival_notified_at TIMESTAMPTZ,
  ADD COLUMN arrival_distance_meters NUMERIC(10,2),
  ADD COLUMN arrival_method VARCHAR(20),
  ADD COLUMN arrival_location_id UUID REFERENCES courier_location_history(id);

ALTER TABLE deliveries
  ADD CONSTRAINT deliveries_arrival_method_check
  CHECK (arrival_method IS NULL OR arrival_method IN ('GEOFENCE','MANUAL'));

CREATE INDEX idx_deliveries_arrival_pending
  ON deliveries(tenant_id,courier_id,status)
  WHERE arrival_detected_at IS NULL AND status IN ('PICKED_UP','IN_TRANSIT');

