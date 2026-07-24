ALTER TABLE courier_availability DROP CONSTRAINT IF EXISTS courier_availability_status_check;
ALTER TABLE courier_availability ADD CONSTRAINT courier_availability_status_check CHECK(status IN('ONLINE','OFFLINE','BUSY','PAUSED','DELIVERING','SUSPENDED'));

CREATE TABLE courier_locations(
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id UUID NOT NULL REFERENCES tenants(id), courier_id UUID NOT NULL REFERENCES courier_profiles(id) ON DELETE CASCADE,
 latitude NUMERIC(10,7) NOT NULL, longitude NUMERIC(10,7) NOT NULL, speed NUMERIC(8,2), heading NUMERIC(6,2), accuracy NUMERIC(8,2) NOT NULL,
 altitude NUMERIC(8,2), provider VARCHAR(30), battery_level INTEGER, gps_timestamp TIMESTAMPTZ NOT NULL, received_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 UNIQUE(tenant_id,courier_id), CHECK(latitude BETWEEN -90 AND 90), CHECK(longitude BETWEEN -180 AND 180), CHECK(accuracy>=0), CHECK(battery_level IS NULL OR battery_level BETWEEN 0 AND 100)
);
CREATE INDEX idx_courier_locations_tenant ON courier_locations(tenant_id,received_at DESC);

CREATE TABLE courier_location_history(
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id UUID NOT NULL REFERENCES tenants(id), courier_id UUID NOT NULL REFERENCES courier_profiles(id) ON DELETE CASCADE,
 delivery_id UUID REFERENCES deliveries(id), latitude NUMERIC(10,7) NOT NULL, longitude NUMERIC(10,7) NOT NULL, speed NUMERIC(8,2), heading NUMERIC(6,2), accuracy NUMERIC(8,2) NOT NULL,
 altitude NUMERIC(8,2), provider VARCHAR(30), battery_level INTEGER, gps_timestamp TIMESTAMPTZ NOT NULL, received_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_location_history_courier_time ON courier_location_history(tenant_id,courier_id,gps_timestamp DESC);
CREATE INDEX idx_location_history_delivery_time ON courier_location_history(tenant_id,delivery_id,gps_timestamp DESC);

CREATE TABLE tracking_events(
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id UUID NOT NULL REFERENCES tenants(id), delivery_id UUID REFERENCES deliveries(id), courier_id UUID REFERENCES courier_profiles(id),
 event_type VARCHAR(60) NOT NULL, latitude NUMERIC(10,7), longitude NUMERIC(10,7), payload JSONB NOT NULL DEFAULT '{}'::jsonb, created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_tracking_events_delivery ON tracking_events(tenant_id,delivery_id,created_at DESC);

CREATE TABLE proof_of_delivery(
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id UUID NOT NULL REFERENCES tenants(id), delivery_id UUID NOT NULL REFERENCES deliveries(id), proof_type VARCHAR(20) NOT NULL,
 object_key VARCHAR(500), comments VARCHAR(500), metadata JSONB NOT NULL DEFAULT '{}'::jsonb, created_by UUID NOT NULL REFERENCES users(id), created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 CHECK(proof_type IN('PHOTO','SIGNATURE','OTP','QR','COMMENT'))
);
CREATE INDEX idx_proof_delivery ON proof_of_delivery(tenant_id,delivery_id,created_at DESC);

CREATE TABLE otp_codes(
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id UUID NOT NULL REFERENCES tenants(id), delivery_id UUID NOT NULL REFERENCES deliveries(id), code_hash VARCHAR(120) NOT NULL,
 expires_at TIMESTAMPTZ NOT NULL, validated_at TIMESTAMPTZ, attempts INTEGER NOT NULL DEFAULT 0, created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_otp_delivery ON otp_codes(tenant_id,delivery_id,created_at DESC);

CREATE TABLE qr_codes(
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id UUID NOT NULL REFERENCES tenants(id), delivery_id UUID NOT NULL REFERENCES deliveries(id), token_hash VARCHAR(120) NOT NULL,
 expires_at TIMESTAMPTZ NOT NULL, scanned_at TIMESTAMPTZ, created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_qr_delivery ON qr_codes(tenant_id,delivery_id,created_at DESC);

CREATE TABLE chat_messages(
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id UUID NOT NULL REFERENCES tenants(id), delivery_id UUID NOT NULL REFERENCES deliveries(id), sender_id UUID NOT NULL REFERENCES users(id),
 sender_type VARCHAR(20) NOT NULL, channel VARCHAR(30) NOT NULL, message VARCHAR(1000) NOT NULL, read_at TIMESTAMPTZ, created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
 CHECK(sender_type IN('CUSTOMER','COURIER','MERCHANT','ADMIN')), CHECK(channel IN('CUSTOMER_COURIER','MERCHANT_COURIER'))
);
CREATE INDEX idx_chat_delivery_time ON chat_messages(tenant_id,delivery_id,created_at);

CREATE TABLE notifications(
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id UUID NOT NULL REFERENCES tenants(id), user_id UUID NOT NULL REFERENCES users(id), delivery_id UUID REFERENCES deliveries(id),
 event_type VARCHAR(60) NOT NULL, title VARCHAR(160) NOT NULL, body VARCHAR(500) NOT NULL, channel VARCHAR(20) NOT NULL DEFAULT 'IN_APP', status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
 read_at TIMESTAMPTZ, sent_at TIMESTAMPTZ, created_at TIMESTAMPTZ NOT NULL DEFAULT now(), CHECK(channel IN('IN_APP','FCM','APNS','WEB_PUSH')), CHECK(status IN('PENDING','SENT','FAILED','READ'))
);
CREATE INDEX idx_notifications_user ON notifications(tenant_id,user_id,created_at DESC);

INSERT INTO permissions(code,module,action,description) VALUES
 ('TRACKING_VIEW','TRACKING','VIEW','Ver seguimiento en tiempo real'),('TRACKING_ADMIN','TRACKING','ADMIN','Administrar seguimiento'),
 ('COURIER_LOCATION_UPDATE','TRACKING','LOCATION_UPDATE','Actualizar ubicación propia'),('PROOF_VIEW','TRACKING','PROOF_VIEW','Ver pruebas de entrega'),
 ('PROOF_CREATE','TRACKING','PROOF_CREATE','Registrar pruebas de entrega'),('CHAT_VIEW','TRACKING','CHAT_VIEW','Ver chat de entregas'),
 ('CHAT_SEND','TRACKING','CHAT_SEND','Enviar mensajes de entrega'),('NOTIFICATION_VIEW','TRACKING','NOTIFICATION_VIEW','Ver notificaciones')
ON CONFLICT(code) DO NOTHING;
INSERT INTO role_permissions(role_id,permission_id) SELECT r.id,p.id FROM roles r CROSS JOIN permissions p WHERE r.code IN('TENANT_ADMIN','PLATFORM_ADMIN') AND p.module='TRACKING' ON CONFLICT DO NOTHING;
