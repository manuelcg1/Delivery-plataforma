# Order detail implementation plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Aplicar el prototipo aprobado conservando la paleta CERKA y mostrar chat exclusivamente en IN_TRANSIT.
**Architecture:** Componentes de presentación puros en order_detail_widgets.dart, consumidos desde commerce_pages.dart. Mantener servicios, estados y navegación existentes.
**Tech Stack:** Flutter, Riverpod, flutter_test.
**Spec:** docs/superpowers/specs/2026-11-07-order-detail-design.md

## Global constraints
Sin cambios a API, base de datos, autenticación, tema global ni lógica de seguimiento. Chat solo con deliveryId no nulo y estado IN_TRANSIT.

## Review focus
Estados anteriores y terminales ocultan chat; entrega ausente lo oculta incluso en IN_TRANSIT; botón mantiene callback; identificadores largos y texto ampliado no desbordan; resumen usa ColorScheme actual.

## Tasks
- [x] Añadir pruebas de widgets para chat, callback, resumen y layout; ejecutar y comprobar fallo antes de implementación.
- [x] Crear componentes visuales y conectarlos a la pantalla conservando navegación, polling, mapa, calificación e historial real.
- [x] Ejecutar pruebas Flutter y análisis, mvn test, lint/build de admin-web y docker compose config. Revisar diff y generar APK debug local para revisión.

## Execution notes
Trabajar sobre los archivos actuales para preservar las modificaciones locales extensas ya presentes; no hacer commits ni restaurar cambios ajenos. El usuario aprobó la implementación de la pantalla actual. Revisión final del diff limitada a este cambio.

Regresión encontrada por prueba de pantalla: RealtimeStatusBanner consultaba ref durante dispose. Guardar el cliente en initState y verificar mounted antes de la microtask evita el acceso al widget desmontado; se conservan connect/disconnect. Las pruebas también desmontan la pantalla y comprueban ausencia de excepciones.

Verificación: 133 pruebas Flutter aprobadas, analyze sin incidencias; Maven con Java 21: 164 casos, 0 fallos, 0 errores, 13 omitidos; admin-web lint sin errores (2 advertencias existentes) y build aprobado; docker compose config --quiet aprobado. APK debug compilado con API/WS 127.0.0.1:8080. Revisión estática independiente sin hallazgos accionables. Evidencias de comandos en .local/order-detail-*.log (no versionadas).

APK instalado por USB con install -r, inicio correcto y sesión conservada. Verificación visual en CPH2531: detalle del pedido ORD-1794088132160-2CE14E muestra resumen, total, conexión en vivo, historial conectado y repartidor; chat oculto para Pedido creado. Captura local: .local/cerka-order-detail-review.png. No se alteraron pedidos para probar estados; IN_TRANSIT y estados terminales se verificaron con pruebas de widgets.
