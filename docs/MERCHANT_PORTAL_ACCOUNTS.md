# Acceso de nuevos comercios al portal

En Administración → Comercios → Nuevo comercio, la sección **Acceso al portal** permite crear una cuenta junto con el comercio. El administrador necesita permisos para crear usuarios y asignar roles. El correo de acceso puede ser diferente del correo comercial.

La contraseña requiere al menos 10 caracteres y admite hasta 72 bytes UTF-8. Se almacena mediante BCrypt; no se devuelve en respuestas ni se guarda en el navegador. Si el correo ya corresponde a una identidad, se rechaza el alta completa sin reemplazar su contraseña. La vinculación por invitación queda fuera de este flujo.

La cuenta recibe `MERCHANT_PORTAL_OPERATOR`, con acceso a pedidos y operación de sus sucursales. No recibe administración de usuarios ni acceso general al catálogo. Su membresía OWNER incorpora automáticamente las nuevas sucursales del mismo comercio. Las asignaciones limitadas de otros operadores se conservan.

El comercio se crea en DRAFT: debe activarse y tener una sucursal para operar. La suspensión bloquea operaciones y entrega de eventos del comercio, incluso en conexiones existentes. No desactiva la identidad global del responsable.

El alta por API sigue admitiendo omitir `portalAccess`. Los comercios existentes no reciben cuentas automáticamente. V35 agrega el rol y los disparadores necesarios sin reemplazar los roles previos.

## Verificación

- Suite backend completa con PostgreSQL real: 145 pruebas, cero fallos, una omitida; incluye migraciones V34 y alta de cuentas con V35.
- Verificación posterior de seguridad WebSocket y eventos: 14 pruebas aprobadas, incluida entrega autorizada, revocación y bloqueo de SEND del cliente.
- Administración: 15 pruebas aprobadas; portal: 23. Lint y compilaciones completados para ambas aplicaciones.
- Imágenes Docker finales construidas para backend, administración y portal.
- Ensayo HTTP aislado aprobado: alta conjunta, login sin código de empresa, pedidos propios y confirmación, rechazo de acceso ajeno, duplicados y suspensión.
- Respaldo local restaurado y comparado antes de aplicar V35; migración validada y segunda ejecución sin cambios pendientes. Registros de negocio y permisos anteriores conservados.
- Activación local completada: backend saludable, administración y portal HTTP 200, doce comprobaciones de imágenes HTTP 200. Producción no desplegada.

El respaldo, ensayo de restauración y resultado de la activación local se registran en `.local/merchant-activation-result.json`. Estos artefactos locales no deben incorporarse al repositorio porque el respaldo contiene datos de negocio.
