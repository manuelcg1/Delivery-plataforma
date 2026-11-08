# Yape por comercio

En administración, la sección **Métodos de pago** permite habilitar Yape y guardar el número asociado, nombre del titular y una imagen QR. El QR se conserva sin recortarlo. No debe usarse el número de quien compra: son los datos del receptor configurados por el comercio.

QR: PNG o JPEG de hasta 5 MB y 4096 píxeles por lado. Número de 9 dígitos que comienza con 9; titular de hasta 160 caracteres. La validación del servidor comprueba también el contenido real de la imagen. Estos límites no cambian los formatos admitidos para logo o banner.

En el APK, **Confirmar pedido** muestra Yape como único método. Abrir la tarjeta permite consultar QR, titular, número e importe total. La opción **Sí, ya realicé mi Yape** registra una declaración del cliente y cambia la tarjeta a verde. Crear el pedido requiere además dirección validada, cobertura disponible y los datos de cobro vigentes.

La declaración no verifica una transferencia: el pago se registra pendiente, sin captura simulada. Cambiar el comercio, importe, dirección o configuración invalida la confirmación previa. Si faltan los datos de Yape o no puede cargarse el QR, no se habilita la confirmación.

## API

- Administración: `GET /api/v1/merchants/{id}/payment-methods/yape`.
- Guardado: `PUT /api/v1/merchants/{id}/payment-methods/yape`, multipart con `enabled`, `phone`, `holderName`, `qr`.
- APK autenticado: `GET /api/v1/customer/checkout/merchants/{id}/yape`.
- Respuesta: `enabled`, `phone`, `holderName`, `qrUrl`, `version`.
- Declaración de pago: `POST /api/v1/orders/{id}/payments`, método `YAPE`, `customerDeclared: true`, `yapeSettingsVersion` vigente e `Idempotency-Key`.

El tenant se deriva exclusivamente del usuario autenticado. La configuración y el pedido deben pertenecer al mismo tenant y comercio. Los QR se guardan en almacenamiento privado y se devuelven mediante URL firmada.

## Compatibilidad

Producción usa `PAYMENT_PROVIDER=MANUAL_YAPE`: permite registrar declaraciones Yape y pagos contra entrega como pendientes; rechaza tarjeta, billetera digital, transferencia y otros métodos simulados. `CASH_ONLY` permite únicamente contra entrega y oculta Yape al APK, por lo que no sirve para su flujo exclusivo de Yape. `SIMULATED` se reserva para desarrollo y el perfil de producción lo rechaza.

En ambos modos de producción, confirmar un pago no ejecuta el proveedor simulado. Yape exige validación real de la transferencia y su declaración no marca el pedido ni el pago como pagado. No existe confirmación automática de Yape.

Los comercios existentes no reciben cuentas ni QR inventados: deben configurar sus datos de Yape para aceptar pedidos mediante este flujo del APK. La API de pagos anterior conserva sus métodos para otros clientes existentes. El alta de comercio y la configuración de medios de pago son operaciones separadas; un reintento de la carga no debe duplicar el comercio ni su acceso al portal.

## Verificación funcional

Validar alta y edición con QR válido; rechazo de imagen vacía/inválida, número inválido y titular ausente; ausencia de datos sin configuración; aislamiento entre tenants; QR inaccesible; cancelación del panel; confirmación y tarjeta verde; cambio de total/dirección/configuración después de confirmar; doble pulsación/reintento; pago manual pendiente sin ejecutar el proveedor simulado. Preservar navegación, cobertura, carrito, pedidos, seguimiento y calificación.
