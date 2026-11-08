# Merchant Yape implementation plan

> **For agentic workers:** Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Configurar Yape por comercio y conectar el checkout APK al prototipo aprobado.
**Architecture:** Servicio modular backend y Flyway; formulario admin modular; modelo/repositorio/panel Flutter. Contrato compartido en la especificación.
**Tech Stack:** Spring Boot/JDBC/Flyway/MinIO, Next.js/TypeScript, Flutter/Riverpod.
**Spec:** docs/superpowers/specs/2026-11-07-merchant-yape-design.md

## Global constraints
Tenant derivado del principal, QR privado firmado; Yape declarado nunca equivale a PAID; preservar pagos legacy y flujos de dirección/cobertura/portal/comercios.

## Review focus
Acceso entre tenants; QR inválido o faltante; configuración o total cambiado después de confirmar; reintento después de alta parcial; intento de aprobación simulada de Yape.

## Tasks
- [x] Backend: migración, DTO/servicio/controladores, configuración Yape y declaración manual de pago; pruebas de validación, aislamiento, idempotencia y ausencia de captura simulada.
- [x] Admin: componente y validadores probados; sección Métodos de pago al crear/editar comercio; subida/reintentos sin duplicar comercio o acceso al portal.
- [x] APK: modelo y pruebas del panel/confirmación; tarjeta Yape única, QR y receptor reales, invalidación por cambios, gating combinado con validación actual y declaración manual al crear.
- [x] Integrar, revisar cambios y ejecutar suites backend/admin/Flutter, lint/build/analyze y docker compose config; compilar APK local. No cambiar configuración de comercios reales ni inventar QR.

## Execution notes
Existen numerosos cambios previos autorizados en el directorio compartido; preservarlos. Ámbitos de archivos separados por backend, admin-web y customer-app. No commits ni publicación.

Reparto: backend_yape implementa configuración y pago manual; admin_yape implementa alta/edición administrativa; flutter_yape implementa confirmación APK. El coordinador revisa contratos, pruebas globales y activación local.

Decisión: QR solo PNG/JPEG, máximo 5 MB/4096 px por lado, para verificar el contenido con el decodificador nativo sin nuevas dependencias. Logo/banner conservan sus formatos. PUT admite permisos CREATE o UPDATE y requiere MEDIA cuando recibe archivo.

Antes de cambios de esquema se generó .local/delivery-before-yape-20261107.dump, SHA-256 C6CF9F5D8DEF8981D45A4AFF78E89232D77F92BBA9E2DB4904A3CECCE987969C; pg_restore --list lo leyó correctamente. Base de pruebas separada: contenedor delivery-yape-tests, puerto 127.0.0.1:55439, sin datos de negocio reales.

Revisión independiente: backend aprobado; admin corrigió dimensiones/decodificación de QR antes del alta y PUT, revisión posterior aprobada; Flutter sin bloqueantes, corregida codificación puntual y ampliada prueba QR real + regreso del fondo. Se conservaron las funcionalidades anteriores.

Verificación intermedia: admin 30 pruebas, lint sin errores (2 advertencias anteriores), imagen Docker final compilada; backend focal 7 pruebas, imagen Docker compilada, PostgreSQL focal con 37 migraciones aprobado después de corregir fixture identity_id; Flutter panel QR real 3 pruebas y analyze sin incidencias. Las primeras ejecuciones globales detectaron únicamente los errores de fixture ya corregidos; suites globales finales en curso.

Respaldo actualizado antes de activación: .local/delivery-yape-before-activation.dump, SHA-256 A340E17377BE70E68D75E66E4041F73EAAFA0CB7C5A13C5E55531B60A841A211. No se asignaron QR, números ni titulares ficticios a comercios existentes.

Resultados finales: 147 pruebas Flutter aprobadas, analyze sin incidencias; suite estándar backend 174 casos (160 aprobados, 14 optativos omitidos), más prueba PostgreSQL Yape aprobada con todas las migraciones. Las pruebas PostgreSQL de identidad/comercios anteriores pasaron en la ejecución extendida; el único error de esa corrida fue el fixture nuevo, corregido y repetido con éxito. Admin 30 pruebas, lint sin errores y build de imagen aprobado. docker compose config --quiet y diff --check aprobados.

Activación local: imágenes backend/admin actualizadas, servicio saludable, administración HTTP200, endpoint checkout sin autenticar HTTP401. Flyway aplicó V37 desde V36; la tabla de configuración empezó vacía. APK debug compilado para 127.0.0.1:8080, instalado por USB y arranque verificado con sesión conservada. Revisión visual en CPH2531: checkout mantiene dirección/cobertura/resumen y muestra Yape; comercio sin configurar muestra indisponibilidad y no permite confirmar. No se crearon pedidos ni transferencias en la prueba del celular. Captura: .local/cerka-yape-check.png. Contenedor/volumen PostgreSQL temporal retirados verificando su ID.

Último ajuste de texto: botón «Crear pedido» en lugar de «Crear pedido y pagar», coherente con la declaración previa de Yape; las 8 pruebas del flujo se repitieron con éxito. APK final recompilado, instalación USB exitosa y arranque Status: ok con proceso activo.
