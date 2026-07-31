# Customer order tracking contract

## REST snapshot

`GET /api/v1/customer/orders/{orderId}/tracking`

Requires `Authorization: Bearer <customer access token>` and role `CUSTOMER`. The order must belong to the authenticated user and tenant. A missing or foreign order returns the same `404 ORDER_TRACKING_NOT_FOUND` response.

```json
{
  "orderId": "5ab00000-0000-0000-0000-000000000000",
  "deliveryId": "2fd00000-0000-0000-0000-000000000000",
  "deliveryStatus": "IN_TRANSIT",
  "courier": {
    "courierId": "9cd00000-0000-0000-0000-000000000000",
    "displayName": "Carlos M."
  },
  "location": {
    "latitude": -12.0464,
    "longitude": -77.0428,
    "speed": 25.0,
    "heading": 180.0,
    "accuracy": 8.0,
    "altitude": 120.0,
    "gpsTimestamp": "2026-07-31T15:30:00Z"
  },
  "updatedAt": "2026-07-31T15:30:01Z",
  "trackingActive": true,
  "stale": false
}
```

Tracking is active only for `PICKED_UP`, `IN_TRANSIT`, and `ARRIVED_AT_CUSTOMER`. Before tracking starts, `location` and `updatedAt` are null. Terminal responses are inactive and may contain the final accepted location. `stale` defaults to a 60-second GPS age threshold and is configurable through `tracking.customer.stale-threshold`.

## STOMP realtime

- WebSocket endpoint: `/api/v1/realtime`
- CONNECT native header: `Authorization: Bearer <customer access token>`
- Subscription: `/user/queue/orders/{orderId}/tracking`
- Never place tokens in query strings or destinations.

Every subscription is authenticated and checked against `orders.customer_id`; the destination is private and events are published with `convertAndSendToUser` only to the owning customer's principal name.

```json
{
  "type": "COURIER_LOCATION_UPDATED",
  "orderId": "5ab00000-0000-0000-0000-000000000000",
  "deliveryId": "2fd00000-0000-0000-0000-000000000000",
  "deliveryStatus": "IN_TRANSIT",
  "location": {
    "latitude": -12.0464,
    "longitude": -77.0428,
    "speed": 25.0,
    "heading": 180.0,
    "accuracy": 8.0,
    "altitude": 120.0,
    "gpsTimestamp": "2026-07-31T15:30:00Z"
  },
  "publishedAt": "2026-07-31T15:30:01Z"
}
```

Event types are `TRACKING_STARTED`, `COURIER_LOCATION_UPDATED`, `DELIVERY_STATUS_CHANGED`, and `TRACKING_STOPPED`. Exact duplicate locations are accepted with HTTP 202 but are neither persisted again nor published. Customer events are dispatched by a transactional listener in `AFTER_COMMIT`.

## Reconnection

1. Connect STOMP with a current access token.
2. Subscribe to the private order destination.
3. Fetch the REST snapshot.
4. Apply newer realtime events.
5. After reconnecting, repeat the REST snapshot request.

The backend does not replay route history through STOMP and exposes no public tracking-history endpoint.
