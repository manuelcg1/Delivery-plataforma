# Delivery Platform v0.1 — Foundation

Base ejecutable para una plataforma SaaS de delivery multicliente.

## Incluye

- Spring Boot + Java 21
- PostgreSQL 16 y Flyway
- Redis 7
- Next.js + TypeScript
- MinIO para archivos
- Mailpit para correo de desarrollo
- Docker Compose
- Base de datos multicliente inicial
- Health checks
- Convenciones para Codex en `AGENTS.md`

## Requisitos

- Docker Desktop funcionando
- Git
- 4 GB de memoria disponibles para Docker recomendados

## Inicio rápido

En PowerShell:

```powershell
cd C:\Users\Manuel\delivery-platafor
Copy-Item .env.example .env
docker compose up -d --build
```

La primera compilación puede tardar varios minutos. Para seguirla en pantalla:

```powershell
docker compose up --build
```

## Verificación

```powershell
docker compose ps
docker compose logs backend --tail 100
docker compose logs admin-web --tail 100
```

Servicios:

- Panel: http://localhost:3000
- API: http://localhost:8080/api/v1/public/health
- Actuator: http://localhost:8080/actuator/health
- MinIO: http://localhost:9001
- Mailpit: http://localhost:8025

## Detener

```powershell
docker compose down
```

Para eliminar también los datos locales:

```powershell
docker compose down -v
```

## Próxima fase

La fase v0.2 implementará identidad: registro de empresa, administrador inicial, inicio de sesión, JWT, refresh tokens, roles, permisos y auditoría.
