# Arquitectura v0.1

## Enfoque

Monolito modular para minimizar costos operativos y complejidad durante el MVP.

## Componentes

- `backend`: API y lógica de negocio.
- `admin-web`: operación administrativa.
- PostgreSQL: fuente principal de datos.
- Redis: caché y datos efímeros.
- MinIO: archivos e imágenes.
- Mailpit: pruebas de correo.

## Multitenencia

La estrategia inicial usa una base compartida y columnas `tenant_id`. Las restricciones e índices incluyen el tenant cuando corresponde.

## Evolución

Solo se separarán servicios cuando existan métricas que demuestren un cuello de botella o necesidad de despliegue independiente.
# Identity v0.2

Identity permanece dentro del monolito y se organiza por `auth`, `user`, `role`, `audit` y `security`. PostgreSQL es la fuente de verdad; Flyway V3 evoluciona instalaciones v0.1. El contexto autenticado contiene `userId`, `tenantId`, `tenantCode`, roles y permisos. Ninguna operación protegida confía en un tenant enviado por el cliente.

Catalog es otro módulo del mismo monolito, organizado por comercio, sucursal, categoría, producto, variante, inventario y catálogo público. Las migraciones V4–V7 agregan el modelo sin alterar Identity. Las relaciones se validan por tenant y comercio en la capa de aplicación, además de claves foráneas y restricciones SQL.
