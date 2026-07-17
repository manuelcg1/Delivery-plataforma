# Identity v0.2

El registro crea tenant, administrador, rol `TENANT_ADMIN`, asignación de permisos y auditoría en una transacción. El login se resuelve por `tenantCode + email`, usa BCrypt y bloquea temporalmente después del límite configurable. Los refresh tokens son aleatorios, se persisten como hash, rotan en cada uso y se revocan al cerrar sesión o restablecer contraseña.

Toda consulta protegida toma `tenantId` del JWT validado. Los DTO de usuarios y roles no aceptan tenant. `TENANT_ADMIN` no puede asignar roles globales y el último administrador activo no puede desactivarse a sí mismo.

Variables: `JWT_SECRET`, `JWT_ACCESS_EXPIRATION_MINUTES`, `JWT_REFRESH_EXPIRATION_DAYS`, `PASSWORD_RESET_EXPIRATION_MINUTES`, `FRONTEND_URL`, `COOKIE_SECURE`, `CORS_ALLOWED_ORIGINS`, `LOGIN_MAX_ATTEMPTS`, `LOGIN_LOCK_MINUTES`, `MAIL_HOST`, `MAIL_PORT`.
