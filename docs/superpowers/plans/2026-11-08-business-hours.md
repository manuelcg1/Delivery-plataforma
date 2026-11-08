# Business hours implementation plan

> **For agentic workers:** Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Configurar horarios en portal y hacerlos cumplir al seleccionar productos y crear pedidos en APK/servidor.
**Architecture:** Servicio compartido backend con Clock y repositorio JDBC; editor por sucursal en portal; lectura fresca de disponibilidad y mensajes Flutter. Reutilizar esquema.
**Tech Stack:** Spring Boot/JDBC, Next.js/TypeScript, Flutter/Riverpod.
**Spec:** docs/superpowers/specs/2026-11-08-business-hours-design.md

## Global constraints
Tenant autenticado, horarios del servidor/sucursal, APIs versionadas, no alterar pedidos previos ni configuraciones reales. Preservar catálogo, Yape y asignación.

## Review focus
Medianoche y cambio de semana; cierre exacto; segundo turno; ausencia de configuración; excepciones; respuestas tardías del selector; datos cacheados del APK; comprobar antes de escritura/pago.

## Tasks
- [x] Backend: evaluador compartido, APIs/validación de horario, endpoint cliente y guardas pedidos con pruebas de tiempo/aislamiento/transacciones.
- [x] Portal: editores accesibles al elegir Todas o una sucursal, días/rangos y segundo turno, carga/error/reintento y pruebas.
- [x] APK: disponibilidad fresca antes de producto/QR/checkout, aviso y gating, pruebas y conservación de flujo.
- [x] Revisar contratos, suites backend/admin/portal/Flutter, lint/build/analyze/config, respaldo y actualización local/APK.

## Execution notes
Hay numerosos cambios anteriores del usuario en el directorio compartido; preservarlos. Comandos privilegiados y suites completas se centralizan en root para evitar esperas de aprobación de subagentes. No commits ni publicación. No pruebas contra datos reales.

Verificación: backend 196 casos sin fallos/errores (17 opcionales omitidos), portal 42 aprobadas, Flutter 165 aprobadas y 17 de QR/pago repetidas tras corrección de resume; analyze sin incidencias. Lint/build admin y portal, imágenes backend/portal y APK final correctos; compose config válido. Revisado el caso de recarga del QR y corregido el manejo temprano de error asíncrono. Backend healthy, portal/admin login HTTP 200. APK instalado y abierto en EY6HFQXG69UKUSP7, puertos reverse 8080/9000 restaurados. Detalles y respaldo en docs/BUSINESS_HOURS.md.
