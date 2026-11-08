# Merchant portal account implementation plan

> **For agentic workers:** Use superpowers:executing-plans inline; review the completed change independently.

**Goal:** Crear el comercio con una cuenta de operador y acceso limitado a sus sucursales.
**Architecture:** Reutilizar identidad global, usuario por tenant, MERCHANT_PORTAL_OPERATOR y merchant_memberships. Un servicio transaccional provisiona la cuenta dentro de la transacción de alta del comercio. DTO de acceso opcional preserva clientes API existentes; la interfaz administrativa lo ofrece activado por defecto. No crear credenciales en merchants.
**Tech Stack:** Java 21, Spring Boot, JDBC, Flyway, PostgreSQL, Next.js/TypeScript.
**Spec:** Auditoría aceptada en esta conversación: alta conjunta, permisos mínimos, sucursales presentes/futuras, aislamiento y validación.

## Constraints and rulings
- Preservar cambios existentes del workspace; no commits ni despliegue productivo.
- Tenant obtenido del principal autenticado; alta de cuenta exige permisos de crear usuarios y asignar roles.
- Correo existente: rechazar sin modificar identidad, comercio ni contraseña. No implementar vinculación silenciosa. Invitación verificada es un flujo separado; no enviar correos ni inventar credenciales.
- Contraseña inicial explícita, mínimo 10 caracteres; nunca devolverla, registrarla en auditoría ni guardarla en almacenamiento del navegador.
- Operador asignado a un comercio con membresía OWNER, sin TENANT_ADMIN; OWNER representa el alcance sobre sus sucursales, no permisos globales.
- Suspensión del comercio deniega operaciones y suscripciones nuevas. Auditar conexiones en curso y eventos sin datos sensibles.

## Tasks and validation
- [x] Prueba roja de alta: cuenta, BCrypt, rol, membresía y tenant; duplicado no sobrescribe; actor sin permisos rechazado; transacción revierte.
- [x] Servicio MerchantAccountProvisioner y DTO opcional portalAccess en alta; frontend con datos del responsable, contraseña/confirmación y acceso opcional.
- [x] V35 actualiza permisos de operador y asigna nuevas sucursales a membresías OWNER sin expandir OPERATOR existentes. Probar migración PostgreSQL real.
- [x] Restringir acceso a comercios inactivos/suspendidos en operaciones y suscripciones; pruebas de aislamiento y regresión.
- [x] Maven completo, admin lint/build/tests, portal lint/build/tests, Compose; revisión independiente.
- [x] Respaldar base local, reconstruir backend/admin locales, comprobar migración y flujo HTTP con datos sintéticos aislados. Documentar límites y resultados.

## Review focus
- Correo existente y concurrencia: sin reasignaciones ni contraseñas reemplazadas.
- Roles inactivos o no configurados: error transaccional claro.
- Sucursales futuras: solo OWNER de ese comercio recibe asignación.
- Estados DRAFT/INACTIVE/SUSPENDED y otro comercio: acceso operativo rechazado para operadores.
- Reintento tras fallo de imagen: no crea usuario o comercio duplicados; credenciales no persistidas.

## Ledger
- Pruebas PostgreSQL de alta: 4/4 aprobadas en merchant-green.
- Regresión de suspensión: reprodujo acceso incorrecto a comercio DRAFT; corregida en contexto y operaciones.
- Rol dedicado: el rol MERCHANT_OPERATOR existente incluye permisos de catálogo de alcance amplio; se conserva y se crea MERCHANT_PORTAL_OPERATOR con permisos de pedidos/reparto.
- Revisión independiente detectó STOMP SEND sin bloqueo y suscripciones existentes sin revalidación; se añaden regresiones y corrección antes del cierre.

- Cierre: ensayo HTTP aprobado; respaldo restaurado y V35 validada en copia y base local, datos anteriores conservados. Backend saludable; admin y portal HTTP 200; 12 comprobaciones de imagen HTTP 200. Sin despliegue productivo.
