# Avisos de llegada al cliente

La llegada (`ARRIVED_AT_CUSTOMER`) y su notificación `COURIER_ARRIVED` se guardan
en la misma transacción. `CourierArrivalEventListener` prepara el aviso antes del
commit; publica WebSocket después. Firebase nunca participa en la transacción de
la entrega.

`ArrivalNotificationOutbox` procesa `notifications` cada 5 segundos. La clave
`COURIER_ARRIVED:<deliveryId>`, junto con tenant y usuario, evita encolar dos veces
la misma llegada. Cada trabajo tiene una reserva temporal de 120 segundos y un
identificador de intento: un proceso reiniciado puede recuperar pendientes y un
trabajador antiguo no puede sobrescribir el resultado de otro.
El envío tiene un presupuesto máximo de 60 segundos y un scheduler propio para
no bloquear las tareas de asignación y reconciliación de repartidores.

Los fallos se reintentan con esperas de 30, 60, 120 y 240 segundos, hasta cinco
intentos. Un aviso de más de 15 minutos expira para no anunciar llegadas antiguas.
`last_error`, `attempt_count`, `last_attempt_at` y `next_attempt_at` permiten
diagnosticar los fallos. No se registran tokens ni credenciales en los logs.

`SENT`, `sent_at` y `arrival_notified_at` indican aceptación por Firebase en al
menos un dispositivo del cliente, **no** lectura ni visualización en el teléfono.
Si otro dispositivo falla después de esa aceptación, se conserva el éxito y el
código del fallo parcial; no se reenvía al dispositivo exitoso. Los tokens que
Firebase declara `UNREGISTERED` se desactivan.

La entrega es al menos una vez: un fallo entre la aceptación de Firebase y el
guardado del resultado puede ocasionar un reenvío. El identificador de evento,
el tag Android y la deduplicación Flutter reducen avisos duplicados; no se promete
entrega exactamente una vez por parte del sistema operativo.

## Aplicación móvil

- `PushNotificationService` comparte permisos, registro/renovación del token,
  recepción en primer plano y apertura desde FCM.
- `DeviceTokenRegistration` serializa registros. Al salir de la sesión se detienen
  callbacks y registros pendientes antes de desactivar el token, tanto para
  clientes como repartidores.
- `CustomerArrivalNotificationService` maneja únicamente llegadas del cliente.
  La navegación usa `orderId`, no `deliveryId`.
- `ArrivalNoticeCoordinator` reúne FCM y WebSocket. Si el seguimiento del pedido
  está visible muestra un aviso dentro de la pantalla; en otras pantallas muestra
  «Ver pedido». La deduplicación se guarda por tenant, usuario y entrega.
- En segundo plano el sistema operativo muestra el payload de notificación de
  FCM. El handler Dart solo crea una alerta para mensajes que contienen datos
  sin notificación, evitando duplicar la alerta nativa.
- Las acciones de asignación, aceptar y rechazar siguen en el servicio del
  repartidor.

## Instalación y diagnóstico

Se requiere aplicar Flyway V32 al desplegar el backend y actualizar la aplicación
móvil. La migración no reenvía llegadas históricas. Se mantienen los requisitos
de Firebase configurado, token activo y permiso del sistema operativo.

Consultar `notifications` por `tenant_id`, `user_id` y `delivery_id`, con
`event_type='COURIER_ARRIVED'`. Códigos relevantes: `FIREBASE_NOT_CONFIGURED`,
`NO_ACTIVE_DEVICE_TOKEN`, códigos de Firebase, `DISPATCH_ERROR`, `RETRY_LIMIT`
y `EXPIRED`. No cambiar manualmente el estado de entrega para provocar reenvíos.

## Pruebas

`mvn test` cubre persistencia atómica, rollback, duplicados, concurrencia,
recuperación de reservas, reintentos, expiración y aislamiento del destinatario.
Las pruebas de outbox también admiten PostgreSQL temporal mediante
`-Darrival.test.jdbcUrl=jdbc:postgresql://127.0.0.1:55439/postgres`; cada prueba
crea y elimina exclusivamente su propio esquema `arrival_test_<uuid>`.

`flutter test` verifica presentación y deduplicación, apertura desde notificaciones,
selección de `orderId` y finalización de registros antes del cierre de sesión.
Las pruebas automatizadas de Firebase sustituyen el transporte externo; una
prueba real del teléfono debe verificar por separado primer plano y segundo plano.

## Auditoría realizada el 26 de septiembre de 2026

| Verificación | Resultado |
| --- | --- |
| Suite backend final con Java 21 (`mvn clean test`) | 120 aprobadas, 0 fallos, 1 prueba condicional de PostgreSQL omitida |
| Suite con PostgreSQL temporal | 120 aprobadas, incluyendo pruebas de opciones de pedidos y concurrencia del outbox; realizada antes de añadir la última prueba de fallo de WebSocket |
| Regresión de atomicidad | Al reintroducir temporalmente `AFTER_COMMIT`, la prueba falla; código corregido restaurado y suite final aprobada |
| Flyway sobre PostgreSQL temporal | 32 migraciones aplicadas y validadas, esquema temporal eliminado |
| Flutter | 110 pruebas aprobadas |
| Análisis Flutter | Sin errores nuevos; permanecen dos campos `_cerkaSoftCoral` sin uso en `courier_pages.dart` |
| Admin web | Lint y build aprobados; advertencias previas de imágenes y CSS |
| Docker Compose | `docker compose config --quiet` aprobado |
| Revisión independiente de código | Sin hallazgos bloqueantes pendientes |
| Android USB | APK debug instalada con actualización conservando datos; inicio y sesión del cliente operativos |
| Push real en primer plano | Firebase aceptó el mensaje técnico y el coordinador registró la presentación |
| Push real en segundo plano | Android registró exactamente una notificación de CERKA en `CERKA_ORDER_ARRIVAL` |

Las pruebas de teléfono utilizaron mensajes técnicos dirigidos únicamente al
dispositivo USB. No modificaron estados de pedidos ni entregas. La navegación por
`orderId`, la deduplicación FCM/WebSocket y el caso de seguimiento visible se
verificaron automáticamente; no se simuló una entrega comercial real en el móvil.

La APK instalada usa la API habitual de producción. **El backend actualizado y
Flyway V32 todavía deben desplegarse en ese servidor** para activar el nuevo flujo
en entregas reales. Esta tarea no realizó ese despliegue ni cambios de datos en
producción.
