ALTER TABLE delivery_addresses
  ADD COLUMN IF NOT EXISTS place_id VARCHAR(255),
  ADD COLUMN IF NOT EXISTS formatted_address VARCHAR(500),
  ADD COLUMN IF NOT EXISTS street VARCHAR(160),
  ADD COLUMN IF NOT EXISTS street_number VARCHAR(40),
  ADD COLUMN IF NOT EXISTS city VARCHAR(100),
  ADD COLUMN IF NOT EXISTS region VARCHAR(100),
  ADD COLUMN IF NOT EXISTS apartment VARCHAR(80),
  ADD COLUMN IF NOT EXISTS delivery_instructions VARCHAR(500),
  ADD COLUMN IF NOT EXISTS location_source VARCHAR(20) NOT NULL DEFAULT 'LEGACY';

UPDATE delivery_addresses
SET formatted_address = address_line
WHERE formatted_address IS NULL;

ALTER TABLE delivery_addresses
  ADD CONSTRAINT ck_delivery_address_latitude CHECK (latitude BETWEEN -90 AND 90),
  ADD CONSTRAINT ck_delivery_address_longitude CHECK (longitude BETWEEN -180 AND 180),
  ADD CONSTRAINT ck_delivery_address_source CHECK (location_source IN ('SEARCH','MAP','CURRENT','LEGACY'));

CREATE INDEX IF NOT EXISTS idx_delivery_addresses_customer
  ON delivery_addresses(tenant_id, customer_id, active);
CREATE INDEX IF NOT EXISTS idx_delivery_addresses_default
  ON delivery_addresses(tenant_id, customer_id, is_default) WHERE active;

ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS delivery_address_text VARCHAR(500),
  ADD COLUMN IF NOT EXISTS delivery_latitude NUMERIC(10,7),
  ADD COLUMN IF NOT EXISTS delivery_longitude NUMERIC(10,7),
  ADD COLUMN IF NOT EXISTS delivery_reference VARCHAR(255),
  ADD COLUMN IF NOT EXISTS delivery_instructions VARCHAR(500);
