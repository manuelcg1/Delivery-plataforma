# Mobile registration implementation plan

> **For agentic workers:** Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Registro/login móvil sin código, teléfono y perfiles con aprobación de repartidor; teléfono de cliente visible al comercio.
**Architecture:** MOBILE_TENANT_CODE en servidor; DTO mobile separado y APIs legadas conservadas; users.phone nullable; contrato customerPhone en pedidos portal.
**Tech Stack:** Spring Boot/Flyway/JDBC, Flutter/Riverpod, Next.js/TypeScript.
**Spec:** docs/superpowers/specs/2026-11-07-mobile-registration-design.md

## Global constraints
Tenant servidor autenticado/configurado, no tenant libre cliente. Roles solo CUSTOMER/COURIER; repartidor INACTIVE hasta administrador. No contraseñas ni datos ficticios, no cambios de cuentas existentes.

## Review focus
Tenant manipulado; rol administrativo manipulado; courier pendiente con contraseña incorrecta; cliente previo sin teléfono; contacto de cuenta distinto al de entrega; rollback de identidad/membresía/perfil; refresh y login admin conservados.

## Tasks
- [x] Backend auth: DTO/registro/login móvil, validación teléfono y pruebas de aislamiento/roles/aprobación/compatibilidad.
- [x] Flutter auth: eliminar campos tenant, teléfono y perfiles; mensajes de activación; pruebas de payload, validación y layout accesible.
- [x] Portal: customerPhone en API y componente/lista/detalle, pruebas contacto y aislamiento sin alterar delivery phone.
- [x] Config local servidor; suites globales y revisiones, backup y actualización de APK/servicios locales (sin migración necesaria).

## Execution notes
El usuario autorizó el cambio y eligió activación administrativa de repartidores. Preservar cambios locales previos, trabajar en ámbitos separados sin commits. Centralizar comandos privilegiados en root: las aprobaciones de subagentes no se heredan y antes produjeron esperas.

La columna users.phone ya existe desde V3: no se añade V38 ni se modifica esquema. Se añade POST /couriers/{id}/activate y botón administrativo para cumplir la aprobación, porque no existía acción de activación. Perfil inactivo no permite disponibilidad ni sesión de repartidor; la activación se audita, exige COURIER_MANAGE y tenant del principal.

Revisión de autenticación: courier pendiente no puede eludir aprobación mediante /login ni refresh; los administradores conservan su acceso. Una contraseña incorrecta no revela aprobación pendiente. La prueba real PostgreSQL descubrió que lockMinutes long requería cast integer al llamar make_interval; se corrigió y la prueba de credenciales incorrectas pasó.

Resultados antes de activación local: Flutter 152 pruebas aprobadas y analyze sin incidencias; admin 33 pruebas y lint sin errores (2 advertencias previas); portal 32 pruebas y lint sin incidencias; backend final 183 casos, 0 fallos/errores y 17 optativos omitidos. Pruebas focales con PostgreSQL temporal: registro de ambos perfiles, datos normalizados, tenant fijo, rechazo previo a aprobación, activación autorizada/idempotente, login posterior y rollback, además de contacto de pedidos; 17 casos (16 aprobados, 1 optativo omitido).

El primer build Docker paralelo agotó el tiempo de una prueba UI del portal bajo contención; se limita Vitest del portal a un trabajador y se construyen servicios secuencialmente. No se elevan timeouts ni se omiten pruebas.

Respaldo local previo a activación: .local/delivery-mobile-auth-before-activation.dump, SHA-256 988AF7BA7056359B8926F50D6A796C38ED5B643D979C0BB35F9F889B05D940D6. Configuración móvil local asignada a 123456789; no se alteraron cuentas reales ni sus teléfonos/contraseñas.

Prueba HTTP detectó que un valor enum no permitido retornaba 500 (sin crear usuario). Se añadió manejo uniforme de HttpMessageNotReadableException como INVALID_REQUEST_BODY/400 y MobileAuthValidationTest confirma que TENANT_ADMIN no alcanza al servicio de registro. El resto de errores conserva sus respuestas existentes.

Imágenes admin y portal compiladas secuencialmente y activadas, ambos login HTTP200. APK compilado, instalado por USB y arranque Status: ok con sesión preservada. Backend final configurado con MOBILE_TENANT_CODE=123456789, actualizado y saludable; arranque valida las 37 migraciones y confirma que no necesita nuevas. Prueba HTTP final: perfil TENANT_ADMIN rechazado400, login sin datos400, activación sin autenticar401. Contenedor/volumen temporal PostgreSQL retirados verificando su ID. No se crearon cuentas de prueba ni pedidos en la base local real.
