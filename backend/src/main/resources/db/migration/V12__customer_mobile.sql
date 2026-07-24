ALTER TABLE delivery_addresses ADD COLUMN IF NOT EXISTS is_default BOOLEAN NOT NULL DEFAULT false;
CREATE UNIQUE INDEX IF NOT EXISTS uq_customer_default_address ON delivery_addresses(customer_id) WHERE is_default AND active;

CREATE TABLE customer_favorites (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id UUID NOT NULL REFERENCES tenants(id),
 customer_id UUID NOT NULL REFERENCES users(id), merchant_id UUID REFERENCES merchants(id), product_id UUID REFERENCES products(id),
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(), CHECK ((merchant_id IS NULL) <> (product_id IS NULL))
);
CREATE UNIQUE INDEX uq_customer_favorite_merchant ON customer_favorites(customer_id,merchant_id) WHERE merchant_id IS NOT NULL;
CREATE UNIQUE INDEX uq_customer_favorite_product ON customer_favorites(customer_id,product_id) WHERE product_id IS NOT NULL;

CREATE TABLE order_ratings (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id UUID NOT NULL REFERENCES tenants(id), order_id UUID NOT NULL REFERENCES orders(id),
 customer_id UUID NOT NULL REFERENCES users(id), score INTEGER NOT NULL CHECK(score BETWEEN 1 AND 5), comment VARCHAR(500),
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(), UNIQUE(order_id,customer_id)
);

CREATE TABLE customer_devices (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id UUID NOT NULL REFERENCES tenants(id), user_id UUID NOT NULL REFERENCES users(id),
 platform VARCHAR(20) NOT NULL CHECK(platform IN('ANDROID','IOS')), token VARCHAR(500) NOT NULL, active BOOLEAN NOT NULL DEFAULT true,
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), UNIQUE(user_id,token)
);
