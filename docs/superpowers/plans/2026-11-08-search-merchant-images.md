# Imágenes de comercios en Buscar

Mostrar logo y banner configurados para cada comercio en los resultados de Buscar. Reutilizar tarjeta de Inicio, conservar descripción en Buscar, búsqueda y navegación existentes; sin llamadas nuevas ni cambios API/pedidos. Desactivar Hero en las tarjetas de Buscar para conservar su navegación sin animación compartida y evitar héroes duplicados en las pestañas.

- [x] Pruebas de imágenes configuradas, filtro y navegación sin imágenes.
- [x] Tarjeta compartida en Inicio/Buscar y respaldos existentes.
- [x] Flutter test/analyze/build, verificaciones mínimas repo, instalación USB y revisión real.

Suite completa Flutter: 171 pruebas aprobadas. Revisión independiente sin hallazgos bloqueantes. No se alteraron APIs, consultas, permisos ni lógica de pedidos.

Análisis Flutter sin incidencias y APK compilado. Backend: 211 casos sin fallos/errores, 17 opcionales omitidos. Administrador lint/build correcto (dos avisos previos de imágenes), compose config válido. APK instalado conservando datos en EY6HFQXG69UKUSP7 y puertos 8080/9000 restaurados. Se abrió Buscar en el celular y se verificaron logos/banners reales de HELADOS y Pizza, además de respaldos para comercios sin imágenes. Captura local `.local/cerka-search-final.png`. No se modificaron datos ni se generaron pedidos.
