CREATE TABLE merchants(id UUID PRIMARY KEY, tenant_id UUID);
CREATE TABLE branches(id UUID PRIMARY KEY, tenant_id UUID, merchant_id UUID, name VARCHAR);
CREATE TABLE users(id UUID PRIMARY KEY, first_name VARCHAR, last_name VARCHAR);
CREATE TABLE merchant_memberships(id UUID PRIMARY KEY, tenant_id UUID, merchant_id UUID, user_id UUID, active BOOLEAN);
CREATE TABLE merchant_branch_assignments(membership_id UUID, branch_id UUID);
CREATE TABLE delivery_addresses(id UUID PRIMARY KEY, phone VARCHAR, address_line VARCHAR, district VARCHAR);
CREATE TABLE orders(id UUID PRIMARY KEY, tenant_id UUID, merchant_id UUID, branch_id UUID, customer_id UUID,
    delivery_address_id UUID, order_number VARCHAR, status VARCHAR, payment_status VARCHAR, total NUMERIC(12,2),
    currency VARCHAR, version INT, created_at TIMESTAMP WITH TIME ZONE, updated_at TIMESTAMP WITH TIME ZONE, notes VARCHAR);
CREATE TABLE order_items(id UUID PRIMARY KEY, tenant_id UUID, order_id UUID, product_name VARCHAR,
    quantity INT, unit_price NUMERIC(12,2), subtotal NUMERIC(12,2), notes VARCHAR);
CREATE TABLE order_item_options(id UUID PRIMARY KEY, tenant_id UUID, order_item_id UUID, option_group_id UUID,
    option_item_id UUID, group_name VARCHAR, item_name VARCHAR, price_adjustment NUMERIC(12,2));
CREATE TABLE deliveries(id UUID PRIMARY KEY, tenant_id UUID, order_id UUID, courier_id UUID, status VARCHAR, created_at TIMESTAMP);
CREATE TABLE delivery_assignments(delivery_id UUID, status VARCHAR, assigned_at TIMESTAMP);
CREATE TABLE courier_profiles(id UUID PRIMARY KEY, user_id UUID);
CREATE TABLE payments(order_id UUID, payment_method VARCHAR, created_at TIMESTAMP);
