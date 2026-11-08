# Editar comercios

En el administrador, abre **Comercios**, selecciona el comercio y edita su detalle.

- **Datos del comercio:** nombre comercial, código, razón social, tipo, correo de contacto, teléfono, moneda, zona horaria y descripción. **Cancelar cambios** recupera los últimos valores guardados.
- **Identidad visual:** permite reemplazar logo y banner por separado. Las imágenes actuales se muestran con URLs firmadas. Se conserva la imagen anterior si falla una carga.
- **Pagos del comercio:** sección Yape existente para QR, número y titular.
- **Acceso al portal del comercio:** correo de ingreso, nombres y apellidos del responsable, y nueva contraseña con confirmación. Deja la contraseña vacía para conservarla; una contraseña formada solo por espacios se rechaza. Se exige al menos 10 caracteres y un máximo de 72 bytes UTF-8.
- **Estado:** conserva los controles existentes de activación y desactivación con su permiso independiente.

El correo de contacto y el correo de ingreso son datos independientes. Cambiar moneda o zona horaria del comercio no reescribe pedidos ni configuraciones propias de sus sucursales.

## Seguridad

Los formularios respetan los permisos y el tenant autenticado. La edición de credenciales requiere permisos de actualización de comercios y usuarios; la lectura requiere consulta de ambos. Solo se muestran cuentas activas de responsables OWNER/MANAGER asociadas al comercio. Las cuentas compartidas entre comercios/empresas o con roles adicionales se muestran sin edición para evitar afectar otros accesos.

No se muestran contraseñas existentes ni hashes. Los cambios de correo o contraseña sincronizan la identidad y el usuario de forma transaccional y revocan los refresh tokens de esa identidad. Los tokens de acceso ya emitidos mantienen su caducidad habitual. Los errores de duplicados se muestran sin sobrescribir el comercio.

APIs nuevas:

- `GET /api/v1/merchants/{id}/logo` y `/banner`: URL firmada de la imagen actual, o `url:null`.
- `GET /api/v1/merchants/{id}/portal-access`: responsables y posibilidad de edición.
- `PUT /api/v1/merchants/{id}/portal-access/{userId}`: correo, nombres y contraseña nueva opcional.

Se reutilizan el esquema y las APIs existentes de datos generales, estado, cargas y Yape. No se requieren migraciones.

## Verificación (2026-11-08)

Backend: 211 casos, sin fallos ni errores; 17 pruebas opcionales de integración omitidas. Administrador: 46 pruebas aprobadas; lint sin errores, con los dos avisos anteriores sobre imágenes. Se revisaron permisos, tenant, identidad compartida, hash canónico, revocación, rollback y respuestas tardías del formulario.

Respaldo anterior al despliegue local: `.local/delivery-before-merchant-edit.dump`, SHA-256 `06145C07AE9C7E8D95B74A1E6610E79436CF913F7C6DCA2143A4475221701830`.

Build de administrador y generación de ambas imágenes correctos. Backend y administrador actualizados localmente; salud del backend `ok`, login de administrador y portal HTTP 200, `docker compose config --quiet` válido. La primera petición al administrador coincidió con el arranque y el reintento respondió 200. No se modificaron comercios reales ni se cambiaron contraseñas durante las pruebas.
