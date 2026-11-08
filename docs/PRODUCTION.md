# Despliegue en producción

## Requisitos

- Servidor Linux con Docker Engine y Compose v2.
- Java 21 y Node 22 solamente si se ejecutan verificaciones fuera de Docker.
- Cuatro nombres DNS apuntando al servidor: panel administrativo, portal de comercios,
  API y archivos.
- Puertos 80 y 443 públicos. PostgreSQL, Redis y MinIO no deben exponerse.
- Un servidor SMTP real.

## Preparación

```bash
cp .env.production.example .env.production
```

Complete todos los valores vacíos. `JWT_SECRET` debe tener al menos 48 caracteres y
`PAYMENT_WEBHOOK_SECRET` al menos 32. Los dominios deben compartir el mismo dominio
registrable para que la cookie HttpOnly funcione como same-site.

`FIREBASE_SERVICE_ACCOUNT_FILE` debe apuntar al archivo de cuenta de servicio
existente en el servidor, fuera del repositorio. Compose lo monta como solo
lectura. Configure también `GOOGLE_MAPS_API_KEY`; ambos valores son obligatorios
en el Compose productivo. `config --quiet` valida la configuración, pero no
comprueba que el archivo Firebase exista ni que sus credenciales sean válidas.

Genere secretos, por ejemplo:

```bash
openssl rand -base64 64
```

Compruebe la configuración antes de construir:

```bash
docker compose --env-file .env.production -f docker-compose.prod.yml config --quiet
```

## Primer arranque

Para crear el propietario inicial, configure temporalmente:

```dotenv
PLATFORM_OWNER_BOOTSTRAP_ENABLED=true
PLATFORM_OWNER_EMAIL=owner@example.com
PLATFORM_OWNER_INITIAL_PASSWORD=una-clave-temporal-larga
```

Después:

```bash
docker compose --env-file .env.production -f docker-compose.prod.yml up -d --build
docker compose --env-file .env.production -f docker-compose.prod.yml ps
curl --fail https://api.example.com/actuator/health
```

Inicie sesión, cambie inmediatamente la contraseña y cambie
`PLATFORM_OWNER_BOOTSTRAP_ENABLED=false`. A continuación, vuelva a aplicar la
configuración.

El Compose productivo utiliza `MANUAL_YAPE`, coherente con el checkout actual del
APK. Yape registra una declaración pendiente de revisión, nunca un cobro confirmado
por el simulador. Efectivo sigue permitido por el backend; tarjeta y billeteras
simuladas permanecen deshabilitadas. No cambie a `SIMULATED` en producción.

Configure `MOBILE_TENANT_CODE` con el código real de la empresa del administrador;
el backend lo utiliza para el registro y acceso del APK sin pedir empresa al cliente.
El valor de ejemplo `your-tenant-code` debe reemplazarse. Verifique que la empresa
exista y esté activa en el servidor. El Compose exige esta variable.

Antes de aceptar pedidos Yape, configure QR, número y titular de cada comercio.
Compruebe la declaración pendiente y su revisión con una transferencia controlada.
Una interrupción después de crear el pedido puede recuperarse desde Pedidos con
la misma clave de declaración. Si se perdió la respuesta de creación y no se conoce
el pedido, no se repite automáticamente la creación ni la transferencia: revise los
pedidos y concilie con el comercio. Cerrar el aviso local no confirma un pago.

## Backup

Realice backups fuera del servidor y cifrados. Como mínimo:

```bash
mkdir -p backups
docker compose --env-file .env.production -f docker-compose.prod.yml exec -T postgres \
  pg_dump -U delivery -d delivery -Fc > backups/delivery-$(date +%Y%m%d-%H%M%S).dump
```

También debe respaldarse el volumen de MinIO. Pruebe mensualmente la restauración en
un ambiente aislado. No ejecute una restauración directamente sobre producción.

## Actualización y rollback

Antes de actualizar:

Para la versión que incorpora V32–V34, consulte también
[el ensayo de respaldo, restauración y migración](V34_RELEASE_VALIDATION.md).
V34 añade columnas obligatorias: coordine el retiro de las réplicas antiguas
antes de aceptar escrituras con el nuevo esquema. Volver únicamente al binario
anterior no constituye un rollback compatible con esta migración.

1. Cree y verifique un backup.
2. Ejecute toda la CI.
3. Etiquete el commit y las imágenes que se desplegarán.
4. Revise las migraciones Flyway pendientes en staging.

Despliegue:

```bash
git pull --ff-only
docker compose --env-file .env.production -f docker-compose.prod.yml build
docker compose --env-file .env.production -f docker-compose.prod.yml up -d
docker compose --env-file .env.production -f docker-compose.prod.yml ps
```

Para rollback, vuelva al tag anterior y reconstruya los contenedores. Las migraciones
de base de datos no se revierten automáticamente: use un procedimiento ensayado o
restaure el backup cuando una migración no sea compatible hacia atrás.

## Verificación posterior

- `https://API_DOMAIN/actuator/health` responde `UP`.
- Swagger y `/v3/api-docs` no están disponibles.
- No hay puertos 5432, 6379, 9000 ni 9001 expuestos públicamente.
- Inicio de sesión, refresh, cierre de sesión y cambio de contraseña funcionan.
- Se verifica aislamiento usando usuarios de dos tenants distintos.
- Se prueba un pedido completo con declaración Yape pendiente y revisión manual del comercio, incluida la recuperación de una declaración interrumpida sin repetir la transferencia.
- Alertas, espacio en disco, expiración TLS y backups están monitorizados.
