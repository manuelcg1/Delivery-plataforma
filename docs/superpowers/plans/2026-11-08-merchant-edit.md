# Edición completa de comercio

Petición: editar los campos existentes de creación desde el detalle del comercio, preservando relaciones y flujo. Reutilizar PUT merchant, endpoints media y configuración Yape. Datos editables: nombre, código, razón social, tipo, correo, teléfono, moneda, zona horaria, descripción; estado con su permiso separado; logo y banner con carga validada. Acceso al portal en sección independiente; alcance de credenciales consultado al usuario, no bloquear datos generales por esa respuesta.

Mantener id/tenant/fechas internos y sucursales/pedidos; no modificar sus registros al editar comercio. Tenant desde auth y soporte de alcance. Evitar sobreescrituras al cambiar de comercio, doble envío y cargas con errores. Guardar datos/media/Yape por secciones con resultado claro. No mostrar contraseñas guardadas ni hashes.

- [x] Formulario general y media en admin, pruebas de precarga/PUT/permisos/error/cambio de id/cargas.
- [x] Backend: validar actualización, código duplicado uniforme, timezone válido, consultas tenant-scoped y pruebas.
- [x] Usuario confirmó editar credenciales; edición segura de identidad exclusiva con permisos y protección de identidades compartidas implementada.
- [x] Suites backend/admin, compose config; build e imágenes locales, respaldo y verificación HTTP.

No commits ni alteraciones de datos reales para probar. Reutilizar checkout actual; no editar APK para esta tarea del administrador.

Completado: backend 211 casos, 0 fallos/errores, 17 opcionales omitidos; administrador 46 pruebas aprobadas, lint sin errores con 2 avisos anteriores, build correcto. Imágenes backend/admin generadas y aplicadas. Backend health ok; admin y portal login HTTP 200, compose config válido. Revisión independiente sin errores importantes. Detalles en docs/MERCHANT_EDITING.md.
