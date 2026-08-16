-- Standard tariff: S/ 1.00 for each started 500-meter block.
-- Existing order and delivery snapshots are intentionally left unchanged.
UPDATE delivery_rates
SET base_fee = 0.00,
    fee_per_km = 2.00,
    updated_at = now();

UPDATE delivery_zones
SET base_delivery_fee = 0.00,
    updated_at = now();
