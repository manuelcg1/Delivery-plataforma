# Registro móvil y contacto del cliente

El APK inicia sesión con correo y contraseña. El registro solicita nombre, apellido, teléfono/WhatsApp, correo, contraseña y uno de dos perfiles: Cliente o Repartidor. El código de empresa no se solicita ni se envía desde el APK.

El backend requiere `MOBILE_TENANT_CODE`, que determina la empresa del acceso móvil. En el entorno local se configura `123456789`. Si falta o la empresa está inactiva, el acceso móvil falla explícitamente; no se elige una empresa al azar. El acceso administrativo conserva su comportamiento anterior y el cliente no puede cambiar el tenant de acceso móvil enviando un código diferente.

Los teléfonos peruanos de nueve dígitos, o precedidos por +51, se normalizan a +51XXXXXXXXX. Se reutiliza `users.phone`, nullable desde la migración V3. No se modifican ni inventan teléfonos de cuentas anteriores y no se requiere cambio de esquema.

## Cliente

`POST /api/v1/auth/register-mobile` recibe `{firstName,lastName,email,password,phone,profile:"CUSTOMER"}`. Crea identidad/membresía y únicamente rol CUSTOMER en una transacción, devuelve sesión móvil y permite ingresar. El portal de comercios recibe `customerPhone` en listado/detalle de sus pedidos. El contacto de entrega `phone` conserva su significado y aparece con etiqueta distinta.

## Repartidor

El mismo endpoint con `profile:"COURIER"` crea el perfil INACTIVE y devuelve `{pendingApproval:true,message}` sin tokens. El APK informa que requiere activación y vuelve al inicio de sesión. No se permite seleccionar un rol administrativo.

En **Administración → Repartidores**, un usuario con `COURIER_MANAGE` puede usar **Activar repartidor**. La API es `POST /api/v1/couriers/{id}/activate`, donde id es el perfil del repartidor. Se limita al tenant autenticado, es idempotente para ACTIVE y no reactiva SUSPENDED. La activación queda auditada y la disponibilidad inicial es OFFLINE.

El registro pendiente no permite iniciar una sesión operativa; la contraseña se comprueba antes de informar la aprobación pendiente. También se comprueba la aprobación al renovar la sesión. Los administradores con permisos de gestión conservan el acceso administrativo.

## Verificación

Probar registro de ambos perfiles, teléfono inválido, JSON con rol no permitido, intento de seleccionar otra empresa, falta de configuración, rollback si falta rol, contraseña incorrecta, entrada antes/después de activación, activación por usuario sin permiso/otro tenant, teléfonos ausentes anteriores y contacto de entrega distinto al de cuenta. Las pruebas PostgreSQL crean bases temporales propias; no registran usuarios de prueba en la base local real.
