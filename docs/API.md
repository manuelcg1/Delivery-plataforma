# API v1

Públicos: `POST /api/v1/auth/register-tenant`, `login`, `refresh`, `forgot-password`, `reset-password`; `GET /api/v1/public/health`.

Autenticados: `POST /api/v1/auth/logout`, `GET /api/v1/auth/me`; CRUD lógico en `/api/v1/users`; CRUD y permisos en `/api/v1/roles`; `GET /api/v1/audit-logs`. Los endpoints protegidos requieren `Authorization: Bearer <accessToken>` y permisos indicados por OpenAPI/Spring Security.

`POST /api/v1/auth/context` permite al rol `ROLE_PLATFORM_OWNER` elegir un tenant operativo enviando `{ "tenantCode": "..." }`. El backend valida que el tenant esté activo, emite un access token con ese contexto y actualiza el refresh token de la sesión. La selección queda auditada; los endpoints no aceptan `tenant_id` operativo desde el cliente. Al volver a iniciar sesión sin código, las identidades con varias membresías usan el último tenant guardado; las identidades legadas ambiguas deben incluir `tenantCode`.

La migración `V34` conserva cada perfil tenant, su contraseña y su historial. Los correos legados repetidos se marcan como conflicto y no se fusionan automáticamente. Una identidad existente solo se vincula a una nueva membresía si se verifica su contraseña actual; cuentas con conflicto histórico requieren resolución verificada antes de vincularse.

Los errores usan `{timestamp,status,error,message,path,details}`. Swagger está en `/swagger-ui/index.html`.

## Commerce Catalog

Los recursos protegidos `/api/v1/merchants`, `/branches`, `/categories`, `/products`, `/variants` e `/inventory` derivan el tenant del JWT y requieren permisos `CATALOG_*`. La lectura pública está bajo `/api/v1/public/catalog` y solo expone comercios y sucursales activos, además de productos publicados y disponibles.
