-- Código de entrega secreto por pedido: solo lo ve el cliente y el repartidor
-- debe ingresarlo para poder marcar el pedido como entregado.
CREATE TABLE order_delivery_codes (
    order_id UUID PRIMARY KEY REFERENCES orders(id) ON DELETE CASCADE,
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    code VARCHAR(5) NOT NULL,
    failed_attempts INTEGER NOT NULL DEFAULT 0,
    locked_until TIMESTAMPTZ,
    validated_at TIMESTAMPTZ,
    validated_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (code ~ '^[ACDEFGHJKMNPQRTUVWXY34679]{5}$'),
    CHECK (failed_attempts >= 0)
);
CREATE INDEX idx_order_delivery_codes_tenant ON order_delivery_codes(tenant_id, order_id);

-- Pedidos en curso al desplegar: se les genera un código para no bloquear su entrega.
INSERT INTO order_delivery_codes(order_id, tenant_id, code)
SELECT o.id, o.tenant_id,
       (SELECT string_agg(substr('ACDEFGHJKMNPQRTUVWXY34679', (floor(random() * 25) + 1)::int, 1), '')
          FROM generate_series(1, 5) g WHERE o.id IS NOT NULL)
  FROM orders o
 WHERE o.status NOT IN ('DELIVERED', 'CANCELLED', 'REJECTED', 'DRAFT');

-- Los códigos OTP heredados ya no pueden solicitarse desde la app del repartidor.
-- Se invalidan los vigentes para que no sirvan como atajo.
UPDATE otp_codes SET expires_at = now() WHERE validated_at IS NULL AND expires_at > now();
