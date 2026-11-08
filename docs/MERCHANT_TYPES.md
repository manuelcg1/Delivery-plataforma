# Tipos de comercio

El administrador muestra etiquetas en español en el alta, listado y detalle. La API conserva códigos estables para guardar y filtrar comercios.

| Código API | Etiqueta |
| --- | --- |
| RESTAURANT | Restaurante |
| GROCERY | Supermercado |
| PHARMACY | Farmacia |
| RETAIL | Tienda minorista |
| DARK_STORE | Tienda de despacho |
| POLLERIA | Pollería |
| BURGERS | Hamburguesas |
| CHIFA | Chifa |
| ICE_CREAM | Heladería |
| BODEGA | Bodegas |
| SERVICES | Servicios |
| OTHER | Otro |

V36 amplía la restricción de PostgreSQL sin reclasificar ni modificar registros existentes. Farmacia reutiliza PHARMACY. La selección sigue siendo de un tipo por comercio; este cambio no introduce categorías que agrupen comercios.

Las etiquetas se reutilizan desde `admin-web/lib/merchant-types.ts`. Los consumidores de la API deben enviar el código, no la etiqueta traducida. Los nuevos valores se aceptan tanto al crear como al editar y filtrar comercios.

## Carrusel de inicio del APK

Debajo de la dirección, el carrusel **Categorías** filtra los comercios del inicio por el `merchantType` recibido de la API. **Todos** y **Ver todos** restablecen la lista. La selección se conserva al actualizar los comercios, y una categoría sin coincidencias muestra un mensaje específico. Los valores ausentes o desconocidos se agrupan en **Otros** y siguen visibles en **Todos**.

El filtro usa los comercios que la API ya permite consultar al cliente. No cambia permisos, tenant, sucursal de pedidos ni categorías de productos. Para que un comercio aparezca en Heladería, su tipo debe estar configurado como ICE_CREAM; no se deduce a partir del nombre comercial.

Verificación del carrusel: 114 pruebas Flutter aprobadas, incluidos filtrado y restablecimiento, categoría vacía a 320 px, conservación del filtro tras refrescar y compatibilidad con texto ampliado. Análisis de los archivos modificados sin incidencias.

Para desplegar, aplicar V36 junto con el backend y después actualizar administración. No revertir la restricción antigua mientras existan comercios con alguno de los tipos nuevos.

## Validación realizada

- Backend completo con Java 21: 164 pruebas, cero fallos, 13 omitidas en la ejecución sin conexión PostgreSQL explícita.
- Integración PostgreSQL ejecutada aparte: seis pruebas aprobadas, incluida persistencia de los 12 tipos y rechazo de valores desconocidos.
- Administración: 16 pruebas aprobadas, lint sin errores (dos advertencias previas sobre imágenes) y compilación aprobada.
- Imágenes Docker de backend y administración construidas correctamente.
- Ensayo HTTP aislado: creación y edición de los 12 tipos, filtrado y rechazo HTTP 400 de tipos inválidos; regresión del alta de cuentas de comercio y operación de pedidos aprobada.
- V36 ensayada sobre un respaldo restaurado y aplicada en la base local: los registros de las 64 tablas de negocio se conservaron íntegros. Backend UP, administración y portal HTTP 200; Compose válido. No se desplegó a producción.
