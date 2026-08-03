ALTER TABLE branches
  ADD COLUMN IF NOT EXISTS formatted_address VARCHAR(500),
  ADD COLUMN IF NOT EXISTS place_id VARCHAR(255),
  ADD COLUMN IF NOT EXISTS city VARCHAR(120),
  ADD COLUMN IF NOT EXISTS region VARCHAR(120),
  ADD COLUMN IF NOT EXISTS coverage_enabled BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS delivery_radius_km NUMERIC(8,2);

ALTER TABLE branches
  ADD CONSTRAINT ck_branch_delivery_radius
    CHECK (delivery_radius_km IS NULL OR delivery_radius_km > 0),
  ADD CONSTRAINT ck_branch_coverage_configuration
    CHECK (NOT coverage_enabled OR delivery_radius_km IS NOT NULL);

CREATE INDEX idx_branches_coverage
  ON branches(tenant_id, merchant_id, id, coverage_enabled)
  WHERE coverage_enabled;
