# Horarios de atención

En el portal del comercio, abre **Horarios**. Con **Todas** aparecen las sucursales asignadas del comercio seleccionado; al elegir una sucursal se muestra solo su horario. Pulsa **Editar horario**, activa los días de atención, indica apertura y cierre y guarda. Puede configurarse un segundo turno por día.

El cierre anterior a la apertura indica un turno que continúa al día siguiente. Por ejemplo, viernes 20:00–02:00 permite pedidos hasta el sábado a las 02:00 (hora de cierre excluida). Se utiliza la zona horaria de la sucursal y el reloj del servidor.

El APK mantiene visible el catálogo, pero consulta la disponibilidad al seleccionar un producto y antes de mostrar el QR de Yape. Fuera de horario muestra **Fuera de horario de atención**. El servidor también impide agregar o actualizar productos, cotizar y crear pedidos fuera de horario. Quitar productos y vaciar el carrito siguen disponibles. Una confirmación de Yape se invalida si el servidor rechaza el pedido por cierre.

Las pausas temporales y los horarios especiales existentes también se respetan. Una fecha especial sustituye el horario regular de ese día; un cierre especial impide continuar un turno de la víspera.

Para conservar el funcionamiento de los comercios existentes, una sucursal activa sin horario guardado sigue aceptando pedidos. Al guardar un horario, los días cerrados o ausentes no reciben pedidos. Guardar los siete días cerrados bloquea todos los días.

## API y acceso

- `GET/PUT /api/v1/branches/{branchId}/business-hours`: permisos de horarios o `MERCHANT_BRANCH_OPERATE`, siempre con validación de tenant, membresía activa y sucursal asignada.
- `GET /api/v1/customer/branches/{branchId}/availability`: cliente autenticado; devuelve `branchId`, `open`, `status`, `timezone`, `nextOpeningAt` y `currentSchedule`.
- Pedido fuera de horario: HTTP 409, código `OUTSIDE_BUSINESS_HOURS`.
- Estados de disponibilidad: `OPEN`, `UNCONFIGURED`, `OUTSIDE_BUSINESS_HOURS`, `CLOSED`, `TEMPORARILY_CLOSED`.

Se reutilizan las tablas existentes; esta funcionalidad no requiere migraciones ni modifica horarios reales automáticamente.

## Validación local (2026-11-08)

- Backend: `mvn test`, 196 casos, 0 fallos, 0 errores, 17 pruebas opcionales de integración omitidas.
- Portal: 42 pruebas aprobadas; lint y build verificados. Administrador: lint y build verificados (dos avisos previos sobre imágenes).
- APK: suite completa de 165 pruebas aprobada; después de la revisión del retorno desde Yape, 17 pruebas de pago/QR aprobadas de nuevo. La regresión detectada de error asíncrono al recargar el QR fue corregida sin ocultar el estado de error del formulario.
- Revisión de aislamiento de tenant, sucursales asignadas, medianoche, pausas, confirmación Yape y rechazo antes de escrituras.
- Respaldo local anterior a actualización: `.local/delivery-before-hours.dump`, SHA-256 `81AC342336F3A9D122E462A7A39DA17DEB9646BB8A6AA6D8D9FAF06848110C49`.

Las pruebas no modificaron horarios ni generaron pedidos en la base real.

Imágenes de backend y portal aplicadas localmente. Salud del backend `ok`, portal y administrador responden HTTP 200. APK final compilado, instalado y abierto en el celular USB; puertos 8080 y 9000 reconectados. `flutter analyze` final sin incidencias y `docker compose config --quiet` válido. Durante la actualización, el backend tardó unos 127 segundos en iniciar y quedó saludable sin reinicios; el primer acceso al portal coincidió con su arranque y el reintento respondió 200.
