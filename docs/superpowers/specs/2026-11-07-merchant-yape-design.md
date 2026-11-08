# Yape por comercio y confirmación en checkout

El usuario aprobó el prototipo de Yape y solicita configurar QR, número y titular al crear un comercio. El método único del checkout APK será Yape. Tocar la tarjeta abre QR, receptor, titular y total; «Sí, ya realicé mi Yape» cierra el panel, pinta la tarjeta verde y habilita crear pedido solo si también pasan dirección/cobertura existentes. La declaración no verifica una transferencia.

Mantener monolito modular, tenant del principal autenticado, DTOs/servicios/controladores, Flyway y medios privados con URL firmada. No modificar funcionalidades de catálogo, acceso al portal, entregas ni pagos legados. Para comercios sin Yape configurado mostrar indisponibilidad explícita sin inventar datos ni habilitar crear pedido. Debe poder configurarse también un comercio existente.

Contrato: GET /api/v1/merchants/{id}/payment-methods/yape (admin) y GET /api/v1/customer/checkout/merchants/{id}/yape (cliente autenticado) devuelven {enabled:boolean,phone:string|null,holderName:string|null,qrUrl:string|null,version:string|null}. PUT multipart /api/v1/merchants/{id}/payment-methods/yape recibe enabled, phone, holderName y qr (archivo opcional al actualizar; requerido para habilitar si aún no existe). Campos de texto y QR validados servidor y cliente. No aceptar tenant_id ni claves de objetos arbitrarias.

El QR admite PNG o JPEG reales de hasta 5 MB y 4096 píxeles por lado, sin recorte. El número requiere 9 dígitos y comenzar con 9; titular de hasta 160 caracteres. Esta restricción aplica solo al QR; logo y banner conservan sus formatos existentes. La limitación evita añadir dependencias de decodificación y permite validar el contenido real de la imagen en el servidor.

POST /api/v1/orders/{id}/payments conserva compatibilidad y añade método YAPE con customerDeclared:true y yapeSettingsVersion:string. Verificar configuración vigente del mismo comercio/tenant, propiedad del pedido y versión. Registrar PENDING con proveedor manual, sin captura ni aprobación simulada. Bloquear cualquier confirmación simulada de Yape. Conservar idempotencia y no registrar secretos.

La confirmación local se vincula a comercio, configuración y total; se invalida al cambiar esos valores, al cambiar dirección/costo y al volver del fondo. Cargar QR vigente al abrir el panel. Respetar carga, errores y reintentos. Mantener navegación y manejo de pedido creado/pago pendiente existentes. No ejecutar pagos reales en pruebas.

Enfoque aprobado: almacenamiento de configuración separado por comercio, endpoint autenticado de lectura para checkout, formulario modular reutilizado en alta/edición, componentes Flutter específicos. Evitar incrustar QR en el catálogo cacheado o modificar el tema global.
