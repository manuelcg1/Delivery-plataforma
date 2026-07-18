CREATE TABLE delivery_addresses (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id UUID NOT NULL REFERENCES tenants(id), customer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 label VARCHAR(80) NOT NULL, recipient_name VARCHAR(160) NOT NULL, phone VARCHAR(40) NOT NULL, address_line VARCHAR(255) NOT NULL,
 district VARCHAR(100), province VARCHAR(100), department VARCHAR(100), country_code VARCHAR(2) NOT NULL DEFAULT 'PE', postal_code VARCHAR(20),
 latitude NUMERIC(10,7), longitude NUMERIC(10,7), reference VARCHAR(255), active BOOLEAN NOT NULL DEFAULT true,
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 CHECK(latitude IS NULL OR latitude BETWEEN -90 AND 90), CHECK(longitude IS NULL OR longitude BETWEEN -180 AND 180));
CREATE INDEX idx_delivery_addresses_owner ON delivery_addresses(tenant_id, customer_id, active);

CREATE TABLE carts (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id UUID NOT NULL REFERENCES tenants(id), customer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 merchant_id UUID NOT NULL REFERENCES merchants(id), branch_id UUID NOT NULL REFERENCES branches(id),
 subtotal NUMERIC(12,2) NOT NULL DEFAULT 0, discount NUMERIC(12,2) NOT NULL DEFAULT 0, tax NUMERIC(12,2) NOT NULL DEFAULT 0,
 delivery_fee NUMERIC(12,2) NOT NULL DEFAULT 0, total NUMERIC(12,2) NOT NULL DEFAULT 0, currency VARCHAR(3) NOT NULL,
 status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE', created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 CHECK(status IN ('ACTIVE','CHECKED_OUT','ABANDONED')), CHECK(subtotal>=0 AND discount>=0 AND tax>=0 AND delivery_fee>=0 AND total>=0));
CREATE UNIQUE INDEX uq_active_cart_customer ON carts(tenant_id,customer_id) WHERE status='ACTIVE';
CREATE INDEX idx_carts_merchant_branch ON carts(tenant_id,merchant_id,branch_id);

CREATE TABLE cart_items (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id UUID NOT NULL REFERENCES tenants(id), cart_id UUID NOT NULL REFERENCES carts(id) ON DELETE CASCADE,
 product_id UUID NOT NULL REFERENCES products(id), product_name VARCHAR(180) NOT NULL, quantity INTEGER NOT NULL, unit_price NUMERIC(12,2) NOT NULL,
 subtotal NUMERIC(12,2) NOT NULL, notes VARCHAR(500), created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 UNIQUE(cart_id,product_id), CHECK(quantity>=1), CHECK(unit_price>=0 AND subtotal>=0));
CREATE INDEX idx_cart_items_cart ON cart_items(tenant_id,cart_id);

CREATE TABLE orders (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id UUID NOT NULL REFERENCES tenants(id), order_number VARCHAR(40) NOT NULL,
 customer_id UUID NOT NULL REFERENCES users(id), merchant_id UUID NOT NULL REFERENCES merchants(id), branch_id UUID NOT NULL REFERENCES branches(id),
 delivery_address_id UUID NOT NULL REFERENCES delivery_addresses(id), status VARCHAR(30) NOT NULL DEFAULT 'PENDING', payment_status VARCHAR(30) NOT NULL DEFAULT 'PENDING',
 subtotal NUMERIC(12,2) NOT NULL, discount NUMERIC(12,2) NOT NULL DEFAULT 0, tax NUMERIC(12,2) NOT NULL DEFAULT 0,
 delivery_fee NUMERIC(12,2) NOT NULL DEFAULT 0, total NUMERIC(12,2) NOT NULL, currency VARCHAR(3) NOT NULL, notes VARCHAR(1000),
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), UNIQUE(tenant_id,order_number),
 CHECK(status IN ('DRAFT','PENDING','CONFIRMED','PREPARING','READY','ASSIGNED','PICKED_UP','ON_THE_WAY','DELIVERED','CANCELLED','REJECTED')),
 CHECK(payment_status IN ('PENDING','AUTHORIZED','PAID','FAILED','REFUNDED')), CHECK(subtotal>=0 AND discount>=0 AND tax>=0 AND delivery_fee>=0 AND total>=0));
CREATE INDEX idx_orders_customer_created ON orders(tenant_id,customer_id,created_at DESC);
CREATE INDEX idx_orders_merchant_status ON orders(tenant_id,merchant_id,status);

CREATE TABLE order_items (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id UUID NOT NULL REFERENCES tenants(id), order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
 product_id UUID NOT NULL REFERENCES products(id), product_name VARCHAR(180) NOT NULL, quantity INTEGER NOT NULL, unit_price NUMERIC(12,2) NOT NULL,
 subtotal NUMERIC(12,2) NOT NULL, notes VARCHAR(500), CHECK(quantity>=1), CHECK(unit_price>=0 AND subtotal>=0));
CREATE INDEX idx_order_items_order ON order_items(tenant_id,order_id);

CREATE TABLE order_status_history (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id UUID NOT NULL REFERENCES tenants(id), order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
 status VARCHAR(30) NOT NULL, notes VARCHAR(500), changed_by UUID REFERENCES users(id), created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 CHECK(status IN ('DRAFT','PENDING','CONFIRMED','PREPARING','READY','ASSIGNED','PICKED_UP','ON_THE_WAY','DELIVERED','CANCELLED','REJECTED')));
CREATE INDEX idx_order_history_order ON order_status_history(tenant_id,order_id,created_at);

INSERT INTO permissions(code,module,action,description) VALUES
 ('ORDERS_CART_VIEW','ORDERS','CART_VIEW','Ver carrito propio'),('ORDERS_CART_MANAGE','ORDERS','CART_MANAGE','Administrar carrito propio'),
 ('ORDERS_CREATE','ORDERS','CREATE','Crear pedidos'),('ORDERS_VIEW','ORDERS','VIEW','Ver pedidos propios'),
 ('ORDERS_STATUS_UPDATE','ORDERS','STATUS_UPDATE','Actualizar estado de pedidos') ON CONFLICT(code) DO NOTHING;
INSERT INTO role_permissions(role_id,permission_id)
 SELECT r.id,p.id FROM roles r CROSS JOIN permissions p WHERE r.code IN ('TENANT_ADMIN','PLATFORM_ADMIN') AND p.module='ORDERS' ON CONFLICT DO NOTHING;
