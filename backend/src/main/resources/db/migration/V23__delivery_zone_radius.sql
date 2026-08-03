ALTER TABLE delivery_zones
  ADD COLUMN IF NOT EXISTS center_latitude NUMERIC(10,7),
  ADD COLUMN IF NOT EXISTS center_longitude NUMERIC(10,7),
  ADD COLUMN IF NOT EXISTS radius_km NUMERIC(10,2);

ALTER TABLE delivery_zones
  ADD CONSTRAINT ck_delivery_zone_center_latitude
    CHECK (center_latitude IS NULL OR center_latitude BETWEEN -90 AND 90),
  ADD CONSTRAINT ck_delivery_zone_center_longitude
    CHECK (center_longitude IS NULL OR center_longitude BETWEEN -180 AND 180),
  ADD CONSTRAINT ck_delivery_zone_radius
    CHECK (radius_km IS NULL OR radius_km > 0);
