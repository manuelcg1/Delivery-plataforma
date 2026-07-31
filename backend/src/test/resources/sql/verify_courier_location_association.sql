SELECT
    h.courier_id,
    h.delivery_id,
    h.latitude,
    h.longitude,
    h.accuracy,
    h.gps_timestamp,
    h.received_at
FROM courier_location_history h
JOIN deliveries d
  ON d.tenant_id = h.tenant_id
 AND d.id = h.delivery_id
 AND d.courier_id = h.courier_id
WHERE h.delivery_id IS NOT NULL
ORDER BY h.received_at DESC
LIMIT 20;
