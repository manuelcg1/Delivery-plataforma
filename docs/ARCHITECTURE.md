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
