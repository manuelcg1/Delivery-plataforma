-- Mantiene el estado de la oferta/asignación alineado con la respuesta y el
-- ciclo de la entrega, siempre dentro del mismo tenant.
CREATE OR REPLACE FUNCTION sync_delivery_assignment_status() RETURNS trigger AS $$
BEGIN
  IF NEW.courier_id IS NULL OR NEW.status = OLD.status THEN
    RETURN NEW;
  END IF;

  IF NEW.status IN ('ACCEPTED', 'ARRIVED_AT_MERCHANT', 'PICKED_UP',
                    'IN_TRANSIT', 'ARRIVED_AT_CUSTOMER', 'DELIVERED') THEN
    UPDATE delivery_assignments
       SET status = 'ACCEPTED', responded_at = COALESCE(responded_at, now())
     WHERE tenant_id = NEW.tenant_id
       AND delivery_id = NEW.id
       AND courier_id = NEW.courier_id
       AND status = 'PENDING';
  ELSIF NEW.status = 'REJECTED' THEN
    UPDATE delivery_assignments
       SET status = 'REJECTED', responded_at = COALESCE(responded_at, now())
     WHERE tenant_id = NEW.tenant_id
       AND delivery_id = NEW.id
       AND courier_id = NEW.courier_id
       AND status = 'PENDING';
  ELSIF NEW.status IN ('CANCELLED', 'FAILED', 'EXPIRED') THEN
    UPDATE delivery_assignments
       SET status = 'CANCELLED', responded_at = COALESCE(responded_at, now())
     WHERE tenant_id = NEW.tenant_id
       AND delivery_id = NEW.id
       AND courier_id = NEW.courier_id
       AND status = 'PENDING';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sync_delivery_assignment_status
AFTER UPDATE OF status ON deliveries
FOR EACH ROW EXECUTE FUNCTION sync_delivery_assignment_status();

-- Repara asignaciones antiguas que avanzaron sin actualizar la respuesta.
UPDATE delivery_assignments da
   SET status = CASE
         WHEN d.status = 'REJECTED' THEN 'REJECTED'
         WHEN d.status IN ('CANCELLED', 'FAILED', 'EXPIRED') THEN 'CANCELLED'
         ELSE 'ACCEPTED'
       END,
       responded_at = COALESCE(da.responded_at, d.updated_at)
  FROM deliveries d
 WHERE d.id = da.delivery_id
   AND d.tenant_id = da.tenant_id
   AND da.status = 'PENDING'
   AND d.status IN ('ACCEPTED', 'ARRIVED_AT_MERCHANT', 'PICKED_UP',
                    'IN_TRANSIT', 'ARRIVED_AT_CUSTOMER', 'DELIVERED',
                    'REJECTED', 'CANCELLED', 'FAILED', 'EXPIRED');

-- Garantiza la notificación para asignaciones activas creadas antes del
-- arreglo de la aplicación.
INSERT INTO notifications(
  tenant_id, user_id, delivery_id, event_type, title, body, status, sent_at
)
SELECT d.tenant_id, cp.user_id, d.id, 'COURIER_ASSIGNED',
       'Nueva entrega asignada',
       'Tienes una nueva entrega pendiente de aceptación', 'SENT', now()
FROM deliveries d
JOIN courier_profiles cp ON cp.id = d.courier_id
                         AND cp.tenant_id = d.tenant_id
WHERE d.status = 'ASSIGNED'
  AND NOT EXISTS (
    SELECT 1 FROM notifications n
    WHERE n.tenant_id = d.tenant_id
      AND n.user_id = cp.user_id
      AND n.delivery_id = d.id
      AND n.event_type = 'COURIER_ASSIGNED'
  );
