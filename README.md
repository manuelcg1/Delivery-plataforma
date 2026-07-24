# Delivery Platform v0.7 — Customer Mobile App

Monolito modular SaaS multicliente con Spring Boot 3/Java 21, PostgreSQL, Redis, panel administrativo Next.js y aplicación Flutter para clientes. Customer App cubre registro, direcciones, catálogo, carrito, checkout, pago, pedidos y seguimiento.

## Ejecutar

```powershell
Copy-Item .env.example .env
# Complete JWT_SECRET con al menos 32 caracteres
docker compose up -d --build
docker compose ps
```

Servicios: panel `http://localhost:3000`, API/health `http://localhost:8080/api/v1/public/health`, Actuator `http://localhost:8080/actuator/health`, Swagger `http://localhost:8080/swagger-ui/index.html`, Mailpit `http://localhost:8025`, MinIO `http://localhost:9001`.

## Desarrollo

```powershell
cd backend; mvn test
cd ../admin-web; npm run lint; npm run build
cd ..; docker compose config
cd ../customer-app; flutter pub get; flutter analyze; flutter test
```

No se crean credenciales demo. Registre el primer tenant en `/register`. El access token vive en memoria; el refresh token se almacena exclusivamente en cookie HttpOnly y su hash SHA-256 en PostgreSQL. En producción use HTTPS, `COOKIE_SECURE=true`, un secreto aleatorio y orígenes CORS explícitos.

Consulte [docs/IDENTITY.md](docs/IDENTITY.md), [docs/API.md](docs/API.md) y [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Producción

El despliegue productivo usa un archivo Compose separado, TLS automático y únicamente
expone los puertos 80/443. No use `docker-compose.yml` para producción.

Consulte [docs/PRODUCTION.md](docs/PRODUCTION.md) para DNS, secretos, primer arranque,
backups, verificación y rollback.
