# Notificaciones del repartidor

## Flujo único de asignación

Los contratos REST existentes se mantienen, pero todos convergen en `MerchantCourierAssignmentService`:

1. Merchant Portal usa `autoAssign` o `manualAssign` por `orderId`.
2. Admin usa `/api/v1/deliveries/{id}/assign` o `/auto-assign`; el controlador delega en `assignDelivery` por `deliveryId`.
3. El servicio valida el tenant autenticado, disponibilidad y capacidad del repartidor.
4. En una transacción persiste `delivery_assignments`, actualiza `deliveries`, historial, capacidad y auditoría.
5. `CourierNotificationService.assignment` inserta un único registro `notifications`, protegido por la clave única `NEW_DELIVERY_ASSIGNMENT:{assignmentId}`.
6. Un evento interno se procesa con `AFTER_COMMIT`: publica `NEW_DELIVERY_ASSIGNMENT` por el `RealtimeGateway` existente y envía el mismo payload por Firebase FCM.
7. Flutter reúne WebSocket y FCM en `CourierNotificationService.receive`, deduplica por `eventId` y muestra una única notificación local.

`DeliveryService.assign` fue eliminado. `DeliveryService` conserva creación, consulta, estados, zonas y administración de repartidores. Los eventos `CourierAssigned`, `ORDER_UPDATED` y `COURIER_ASSIGNMENT_PENDING` dirigidos a clientes y comercios se conservan por compatibilidad, pero ya no notifican al repartidor.

`TransactionalCourierTrackingEventPublisher` sigue dedicado al tracking GPS y estados del cliente. La asignación utiliza su propio evento transaccional `PushDispatch` y `CourierPushDispatchListener`, también en fase `AFTER_COMMIT`, porque su audiencia y payload son distintos.

## Cliente y seguridad

La app registra el token autenticado en `/api/v1/couriers/me/device-tokens` y lo desactiva al cerrar sesión. En primer plano consume STOMP; en segundo plano o con el proceso cerrado consume mensajes FCM de datos. Al reconectar consulta entregas `ASSIGNED` como recuperación visual, sin generar registros ni Push nuevos.

El canal Android `CERKA_NEW_DELIVERY` usa importancia máxima, visibilidad pública, vibración, badge, categoría de llamada y acciones Aceptar/Rechazar. No usa full-screen intent.

Android usa `android/app/google-services.json`, excluido de Git. En el servidor debe definirse `FIREBASE_SERVICE_ACCOUNT_FILE`; Docker monta la cuenta como secreto de solo lectura y configura `GOOGLE_APPLICATION_CREDENTIALS`. Nunca debe almacenarse la cuenta privada en el repositorio.
