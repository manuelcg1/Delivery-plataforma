CREATE TABLE merchants (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id UUID NOT NULL REFERENCES tenants(id), code VARCHAR(80) NOT NULL,
 name VARCHAR(160) NOT NULL, legal_name VARCHAR(160), description TEXT, merchant_type VARCHAR(30) NOT NULL,
 tax_document_type VARCHAR(30), tax_document_number VARCHAR(60), email VARCHAR(254), phone VARCHAR(40),
 status VARCHAR(30) NOT NULL DEFAULT 'DRAFT', logo_object_key VARCHAR(500), banner_object_key VARCHAR(500),
 default_currency VARCHAR(3) NOT NULL DEFAULT 'PEN', timezone VARCHAR(80) NOT NULL DEFAULT 'America/Lima',
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 UNIQUE(tenant_id,code), CHECK(merchant_type IN ('RESTAURANT','GROCERY','PHARMACY','RETAIL','DARK_STORE','OTHER')),
 CHECK(status IN ('DRAFT','ACTIVE','INACTIVE','SUSPENDED')), CHECK(default_currency ~ '^[A-Z]{3}$'));
CREATE UNIQUE INDEX uq_merchant_tax_tenant ON merchants(tenant_id,tax_document_number) WHERE tax_document_number IS NOT NULL;
CREATE INDEX idx_merchants_tenant_status ON merchants(tenant_id,status);

CREATE TABLE branches (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id UUID NOT NULL REFERENCES tenants(id), merchant_id UUID NOT NULL REFERENCES merchants(id),
 code VARCHAR(80) NOT NULL, name VARCHAR(160) NOT NULL, description TEXT, phone VARCHAR(40), email VARCHAR(254), address_line VARCHAR(255) NOT NULL,
 district VARCHAR(100), province VARCHAR(100), department VARCHAR(100), country_code VARCHAR(2) NOT NULL DEFAULT 'PE', postal_code VARCHAR(20),
 latitude NUMERIC(10,7), longitude NUMERIC(10,7), timezone VARCHAR(80) NOT NULL DEFAULT 'America/Lima', status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE',
 preparation_time_minutes INTEGER, minimum_order_amount NUMERIC(12,2), created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 UNIQUE(tenant_id,merchant_id,code), CHECK(latitude BETWEEN -90 AND 90), CHECK(longitude BETWEEN -180 AND 180),
 CHECK(status IN ('ACTIVE','INACTIVE','TEMPORARILY_CLOSED')), CHECK(minimum_order_amount IS NULL OR minimum_order_amount>=0));
CREATE INDEX idx_branches_tenant_merchant ON branches(tenant_id,merchant_id);

CREATE TABLE business_hours (id UUID PRIMARY KEY DEFAULT gen_random_uuid(),tenant_id UUID NOT NULL REFERENCES tenants(id),branch_id UUID NOT NULL REFERENCES branches(id),day_of_week SMALLINT NOT NULL,open_time TIME,close_time TIME,closed BOOLEAN NOT NULL DEFAULT false,second_open_time TIME,second_close_time TIME,created_at TIMESTAMPTZ NOT NULL DEFAULT now(),updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),UNIQUE(branch_id,day_of_week),CHECK(day_of_week BETWEEN 1 AND 7));
CREATE TABLE branch_special_hours (id UUID PRIMARY KEY DEFAULT gen_random_uuid(),tenant_id UUID NOT NULL REFERENCES tenants(id),branch_id UUID NOT NULL REFERENCES branches(id),special_date DATE NOT NULL,open_time TIME,close_time TIME,closed BOOLEAN NOT NULL DEFAULT false,reason VARCHAR(255),created_at TIMESTAMPTZ NOT NULL DEFAULT now(),updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),UNIQUE(branch_id,special_date));

CREATE TABLE categories (id UUID PRIMARY KEY DEFAULT gen_random_uuid(),tenant_id UUID NOT NULL REFERENCES tenants(id),merchant_id UUID NOT NULL REFERENCES merchants(id),parent_id UUID REFERENCES categories(id),code VARCHAR(80) NOT NULL,name VARCHAR(160) NOT NULL,description TEXT,image_object_key VARCHAR(500),sort_order INTEGER NOT NULL DEFAULT 0,active BOOLEAN NOT NULL DEFAULT true,created_at TIMESTAMPTZ NOT NULL DEFAULT now(),updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),UNIQUE(tenant_id,merchant_id,code));
CREATE INDEX idx_categories_tenant_merchant ON categories(tenant_id,merchant_id,active);

CREATE TABLE products (id UUID PRIMARY KEY DEFAULT gen_random_uuid(),tenant_id UUID NOT NULL REFERENCES tenants(id),merchant_id UUID NOT NULL REFERENCES merchants(id),category_id UUID REFERENCES categories(id),sku VARCHAR(100),slug VARCHAR(180) NOT NULL,name VARCHAR(180) NOT NULL,short_description VARCHAR(300),description TEXT,product_type VARCHAR(30) NOT NULL DEFAULT 'SIMPLE',base_price NUMERIC(12,2) NOT NULL,currency VARCHAR(3) NOT NULL DEFAULT 'PEN',tax_rate NUMERIC(5,2),preparation_time_minutes INTEGER,track_inventory BOOLEAN NOT NULL DEFAULT false,stock_quantity NUMERIC(12,3),low_stock_threshold NUMERIC(12,3),available BOOLEAN NOT NULL DEFAULT true,featured BOOLEAN NOT NULL DEFAULT false,status VARCHAR(30) NOT NULL DEFAULT 'DRAFT',sort_order INTEGER NOT NULL DEFAULT 0,created_at TIMESTAMPTZ NOT NULL DEFAULT now(),updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),UNIQUE(tenant_id,merchant_id,slug),CHECK(product_type IN ('SIMPLE','VARIABLE','COMBO','SERVICE')),CHECK(status IN ('DRAFT','PUBLISHED','UNPUBLISHED','ARCHIVED')),CHECK(base_price>=0),CHECK(stock_quantity IS NULL OR stock_quantity>=0),CHECK(currency ~ '^[A-Z]{3}$'));
CREATE UNIQUE INDEX uq_product_sku_merchant ON products(tenant_id,merchant_id,sku) WHERE sku IS NOT NULL;
CREATE INDEX idx_products_tenant_merchant_status ON products(tenant_id,merchant_id,status);

CREATE TABLE product_variants (id UUID PRIMARY KEY DEFAULT gen_random_uuid(),tenant_id UUID NOT NULL REFERENCES tenants(id),product_id UUID NOT NULL REFERENCES products(id),sku VARCHAR(100),name VARCHAR(160) NOT NULL,price NUMERIC(12,2) NOT NULL,compare_at_price NUMERIC(12,2),cost_price NUMERIC(12,2),track_inventory BOOLEAN NOT NULL DEFAULT false,stock_quantity NUMERIC(12,3),low_stock_threshold NUMERIC(12,3),available BOOLEAN NOT NULL DEFAULT true,active BOOLEAN NOT NULL DEFAULT true,sort_order INTEGER NOT NULL DEFAULT 0,created_at TIMESTAMPTZ NOT NULL DEFAULT now(),updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),CHECK(price>=0),CHECK(compare_at_price IS NULL OR compare_at_price>=price),CHECK(stock_quantity IS NULL OR stock_quantity>=0));
CREATE INDEX idx_variants_tenant_product ON product_variants(tenant_id,product_id);
