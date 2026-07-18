# Payments & Delivery v0.5

`CASH_ON_DELIVERY` crea un pago pendiente que se liquida al completar la entrega. `CARD` usa el adaptador `SIMULATED`: una referencia con `DECLINE` rechaza; las demás aprueban. Las operaciones críticas exigen `Idempotency-Key`.

El webhook es `POST /api/v1/webhooks/payments/SIMULATED`, con `X-Webhook-Signature` igual a `PAYMENT_WEBHOOK_SECRET`. `externalEventId` evita duplicados. No se reciben ni almacenan datos de tarjeta.

Para delivery, cree una zona en `/delivery-zones`, un perfil en `/couriers` y cambie su disponibilidad a `ONLINE`. Cotice en `/delivery/quote`, cree en `/orders/{id}/delivery` y asigne manual o automáticamente.

Flujo: `PENDING → SEARCHING_COURIER → ASSIGNED → ACCEPTED → ARRIVED_AT_MERCHANT → PICKED_UP → IN_TRANSIT → ARRIVED_AT_CUSTOMER → DELIVERED`. Cada cambio usa versionado optimista, historial y sincronización con Orders. La cobertura inicial compara distrito y usa una distancia simulada de 3 km.
