# Delivery Platform v0.3 — Commerce Catalog

Monolito modular SaaS multicliente con Spring Boot 3/Java 21, PostgreSQL, Redis y panel administrativo Next.js. Incluye Identity v0.2 y el núcleo de Commerce Catalog: comercios, sucursales, categorías, productos, variantes, publicación, inventario y catálogo público.

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
```

No se crean credenciales demo. Registre el primer tenant en `/register`. El access token vive en memoria; el refresh token se almacena exclusivamente en cookie HttpOnly y su hash SHA-256 en PostgreSQL. En producción use HTTPS, `COOKIE_SECURE=true`, un secreto aleatorio y orígenes CORS explícitos.

Consulte [docs/IDENTITY.md](docs/IDENTITY.md), [docs/API.md](docs/API.md) y [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
