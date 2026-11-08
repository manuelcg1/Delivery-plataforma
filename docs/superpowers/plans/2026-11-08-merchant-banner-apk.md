# Banner y catálogo visual del comercio

Prototipo aprobado por el usuario: banner superior del comercio y productos con imagen, descripción, precio y acceso al detalle, respetando paleta CERKA. Cambio visual del APK únicamente; no modificar APIs, disponibilidad, carrito, pago, favoritos ni selección de opciones.

Usar `Merchant.bannerUrl` y las imágenes existentes de Product. Si falta/falla una imagen, usar respaldo visual sin bloquear catálogo. No inventar estados de atención ni datos del comercio. Conservar callback actual de selección, incluida consulta fresca de horario antes de navegar.

- [x] Componentes pequeños para encabezado/banner y fila de producto, con pruebas de URL real, respaldo, accesibilidad/320px y callback.
- [x] Integrar en MerchantPage sin alterar acciones ni flujo; mantener búsqueda y mensajes vacíos.
- [x] Pruebas completas Flutter, analyze sin incidencias, compilación APK correcta; checks mínimos del repositorio y revisión.
- [x] APK instalado en EY6HFQXG69UKUSP7 conservando datos; puertos 8080/9000 restaurados y apertura verificada.

No modificar datos reales ni configuración de comercios. No se añaden estados de abierto/cerrado a partir de suposiciones. Mantener todos los cambios previos del usuario.

Pruebas Flutter completas: 169 aprobadas. La prueba existente de selección ahora desplaza la lista antes de tocar el producto, ya que el banner ocupa espacio visible. Backend mínimo: 211 casos sin fallos ni errores (17 opcionales omitidos); admin lint/build correctos con dos avisos previos de imágenes; compose config válido. Revisión independiente del cambio visual sin hallazgos importantes. No cambios en API, datos ni lógica de pedidos.

Verificación visual real: se abrió HELADOS en el celular conectado y se comprobó su banner, logo y producto con imagen/precio/Ver detalle, sin desbordamientos visibles. Captura local `.local/cerka-banner-detail.png`. No se realizaron pedidos, cambios de cuenta ni modificaciones de comercios durante la comprobación. Backend health ok.
