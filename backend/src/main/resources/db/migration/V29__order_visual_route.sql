ALTER TABLE orders
  ADD COLUMN route_polyline TEXT,
  ADD COLUMN route_provider VARCHAR(30),
  ADD COLUMN route_generated_at TIMESTAMPTZ;

ALTER TABLE orders ADD CONSTRAINT orders_route_provider_check
  CHECK (route_provider IS NULL OR route_provider IN ('OSRM','GOOGLE_ROUTES'));

CREATE INDEX idx_orders_route_retry
  ON orders(tenant_id,status)
  WHERE route_polyline IS NULL AND status IN ('PICKED_UP','ON_THE_WAY');
