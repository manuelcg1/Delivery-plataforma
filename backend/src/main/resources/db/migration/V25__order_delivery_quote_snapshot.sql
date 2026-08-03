ALTER TABLE orders
  ADD COLUMN delivery_distance_km NUMERIC(10,2),
  ADD COLUMN delivery_base_fee NUMERIC(12,2),
  ADD COLUMN delivery_fee_per_km NUMERIC(12,2),
  ADD COLUMN delivery_minimum_fee NUMERIC(12,2),
  ADD COLUMN delivery_maximum_fee NUMERIC(12,2),
  ADD COLUMN delivery_free_threshold NUMERIC(12,2),
  ADD COLUMN delivery_free_applied BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN delivery_fallback_applied BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN delivery_zone_id UUID REFERENCES delivery_zones(id),
  ADD COLUMN delivery_quote_created_at TIMESTAMPTZ;

ALTER TABLE orders
  ADD CONSTRAINT ck_orders_delivery_quote_money
  CHECK (
    (delivery_distance_km IS NULL OR delivery_distance_km >= 0) AND
    (delivery_base_fee IS NULL OR delivery_base_fee >= 0) AND
    (delivery_fee_per_km IS NULL OR delivery_fee_per_km >= 0) AND
    (delivery_minimum_fee IS NULL OR delivery_minimum_fee >= 0) AND
    (delivery_maximum_fee IS NULL OR delivery_maximum_fee >= 0) AND
    (delivery_free_threshold IS NULL OR delivery_free_threshold >= 0)
  );

CREATE INDEX idx_orders_delivery_zone
  ON orders(tenant_id, delivery_zone_id)
  WHERE delivery_zone_id IS NOT NULL;
