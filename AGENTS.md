# Instrucciones para Codex

## Principios

- Mantener un monolito modular; no crear microservicios sin una necesidad comprobada.
- Todo dato de negocio debe aislarse por `tenant_id`.
- El tenant se obtiene del usuario autenticado; nunca se confía en un `tenant_id` libre enviado por el cliente.
- Separar entidades, DTOs, servicios y controladores.
- No exponer entidades JPA directamente.
- Usar migraciones Flyway para cambios de esquema.
- Añadir pruebas a cada funcionalidad nueva.
- No almacenar secretos en el repositorio.

## Convenciones

- Backend: paquetes por módulo de negocio.
- API: prefijo `/api/v1`.
- Errores: estructura uniforme y códigos HTTP correctos.
- Frontend: TypeScript estricto, componentes pequeños y accesibles.
- Commits: cambios pequeños y verificables.

## Verificación mínima

Antes de cerrar una tarea:

```bash
cd backend && mvn test
cd admin-web && npm run lint && npm run build
docker compose config
```
