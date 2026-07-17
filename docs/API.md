# API v1

Públicos: `POST /api/v1/auth/register-tenant`, `login`, `refresh`, `forgot-password`, `reset-password`; `GET /api/v1/public/health`.

Autenticados: `POST /api/v1/auth/logout`, `GET /api/v1/auth/me`; CRUD lógico en `/api/v1/users`; CRUD y permisos en `/api/v1/roles`; `GET /api/v1/audit-logs`. Los endpoints protegidos requieren `Authorization: Bearer <accessToken>` y permisos indicados por OpenAPI/Spring Security.

Los errores usan `{timestamp,status,error,message,path,details}`. Swagger está en `/swagger-ui/index.html`.

## Commerce Catalog

Los recursos protegidos `/api/v1/merchants`, `/branches`, `/categories`, `/products`, `/variants` e `/inventory` derivan el tenant del JWT y requieren permisos `CATALOG_*`. La lectura pública está bajo `/api/v1/public/catalog` y solo expone comercios y sucursales activos, además de productos publicados y disponibles.
