ALTER TABLE delivery_assignments
  ADD COLUMN IF NOT EXISTS previous_order_status VARCHAR(30),
  ADD COLUMN IF NOT EXISTS result_message VARCHAR(255);

ALTER TABLE courier_profiles
  ADD COLUMN IF NOT EXISTS vehicle_plate VARCHAR(20);

INSERT INTO permissions(code,module,action,description) VALUES
 ('MERCHANT_ORDER_VIEW','MERCHANT','ORDER_VIEW','Ver pedidos del comercio'),
 ('MERCHANT_DELIVERY_ASSIGN','MERCHANT','DELIVERY_ASSIGN','Asignar repartidor a pedidos'),
 ('MERCHANT_DELIVERY_VIEW_COURIERS','MERCHANT','DELIVERY_VIEW_COURIERS','Ver repartidores disponibles'),
 ('MERCHANT_ORDER_HAND_TO_COURIER','MERCHANT','ORDER_HAND_TO_COURIER','Entregar pedido al repartidor')
ON CONFLICT(code) DO NOTHING;

INSERT INTO role_permissions(role_id,permission_id)
SELECT r.id,p.id FROM roles r CROSS JOIN permissions p
WHERE r.code IN('TENANT_ADMIN','PLATFORM_ADMIN','ROLE_PLATFORM_OWNER')
   OR (r.code='MERCHANT_OPERATOR' AND p.code IN(
      'MERCHANT_ORDER_VIEW','MERCHANT_DELIVERY_ASSIGN',
      'MERCHANT_DELIVERY_VIEW_COURIERS','MERCHANT_ORDER_HAND_TO_COURIER'))
ON CONFLICT DO NOTHING;

CREATE UNIQUE INDEX IF NOT EXISTS uq_delivery_pending_assignment
  ON delivery_assignments(tenant_id,delivery_id) WHERE status='PENDING';

CREATE INDEX IF NOT EXISTS idx_delivery_assignments_expiry
  ON delivery_assignments(expires_at) WHERE status='PENDING';
