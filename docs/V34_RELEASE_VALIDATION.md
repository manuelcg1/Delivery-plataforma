# Validación de V34 y cierre de versión

## Activación del entorno local — 3 de octubre de 2026

Se reconstruyó la imagen de Compose del backend con `mvn package` (incluye
las pruebas; compilación terminada con código 0) y se actualizó la base local
`delivery` de V31 a V34. Esta actuación no despliega el servidor productivo.

Con el backend detenido se generó el respaldo
`backups/delivery-before-local-v34-45969644b59340f0ae0103774594b083.dump`,
SHA-256 `43542dbe78540d1f5b86a0347d9ac913e13762613709ce5c2f452a607575bd51`.
Se restauró en una base temporal propia y se compararon las huellas y cantidades
de las 62 tablas de negocio. Después de migrar se verificó la preservación de
los datos, admitiendo únicamente los cambios previstos por V32–V34, así como
las contraseñas, las membresías y el contexto de los refresh tokens.
La base temporal de restauración fue eliminada.

El backend arrancó saludable, sin reinicios, y validó las 34 migraciones.
La respuesta de validación de `/api/v1/auth/login-mobile` ya no exige
`tenantCode`. La cuenta reportada tiene identidad y membresía activas, sin
conflicto de correo. No se probó ni se modificó su contraseña.

El mismo JAR instalado pasó una prueba HTTP en una base temporal aislada:
registro, `/me`, rechazo sin autenticación, login sin empresa, refresh,
logout y rechazo del refresh revocado. La base y el contenedor de esa prueba
se eliminaron. Evidencias locales: `.local/login-activation-result.json`,
`.local/login-activation-migrations.log` y `.local/login-smoke-result.json`.

Admin-web pasó lint (dos advertencias existentes) y build; Flutter pasó sus
110 pruebas. Se compiló e instaló el APK debug con API
`http://127.0.0.1:8080` y WebSocket `ws://127.0.0.1:8080/api/v1/realtime`,
con los puertos USB 8080 y 9000 redirigidos. La comprobación interactiva con
la contraseña del usuario queda a cargo del usuario; no se solicita su secreto.

El problema de firma de imágenes de MinIO se corrigió después de esta activación;
véase la validación siguiente.

### Imágenes de comercios y productos — corregidas el 3 de octubre de 2026

`MinioCatalogStorage` ahora firma directamente con `MINIO_PUBLIC_ENDPOINT`,
sin sustituir el host de una URL previamente firmada con el endpoint interno.
El cliente interno sigue atendiendo las operaciones de almacenamiento. La región
del firmante se declara explícitamente (`MINIO_REGION`, por defecto `us-east-1`)
para evitar consultas de región a la dirección pública desde Docker. Los objetos
siguen siendo privados y las URLs conservan su vencimiento de 15 minutos.

Tres pruebas de regresión verifican criptográficamente la firma SigV4 de la URL
recibida por el cliente, incluidos host público, puertos y espacios en la ruta.
Fallaron con la implementación anterior y pasaron con la corrección. La suite
backend completa registró 139 casos: 132 aprobados, 0 fallos, 0 errores y 7 omitidos
(las seis pruebas PostgreSQL optativas y la prueba condicional de comercios).
Admin-web pasó lint y build, con las dos advertencias existentes sobre imágenes.
La imagen Docker se reconstruyó con sus pruebas y Compose validó su configuración.

Se actualizó únicamente el backend local, se renovó la versión de caché de los
catálogos afectados y se verificó salud correcta sin reinicios. Las cinco imágenes
almacenadas (tres de producto, un logo y un banner) respondieron HTTP 200 con su
tipo de imagen; también se descargaron las tres imágenes devueltas por la API
pública de productos. No fue necesario modificar ni reinstalar el APK.

En el teléfono conectado por USB se confirmó visualmente el logo y banner del
comercio Pizza, y la fotografía de Pizza Grande en su catálogo. Evidencias locales:
`.local/images-live-result.json`, `.local/images-phone-after.png`,
`.local/images-phone-products.png` y `.local/v34-images-green.log`.
La corrección no se desplegó en producción.

Validación: 2026-09-26; cierre: 2026-09-27. Alcance: identidad global, membresías por tenant y regresiones
de autenticación, junto con las funcionalidades de notificación ya presentes.

## Resultado

| Comprobación | Resultado |
| --- | --- |
| Backend, `mvn clean verify`, JDK 21 | BUILD SUCCESS: 136 casos, 135 aprobados, 0 fallos, 0 errores, 1 omitido condicional |
| PostgreSQL 16.15 y Flyway | 6/6 pruebas aprobadas, incluidas en la suite backend |
| Admin web | 7/7 pruebas; lint sin errores y build aprobado; 2 advertencias existentes sobre imágenes |
| Portal de comercios | 20/20 pruebas; lint y build aprobados |
| Flutter | 110/110 pruebas; análisis sin incidencias; formato de 79 archivos correcto |
| Compose | Configuración local aprobada; configuración productiva aprobada con los valores ficticios del workflow de CI |
| Revisión independiente | Sin hallazgos bloqueantes pendientes en las correcciones |
| Arranque del JAR | Base vacía y copia de datos locales; perfil `prod`, salud pública, liveness, readiness y salud agregada correctas |
| Flujo HTTP real | Registro, `/me`, rechazo 401 sin autenticación, login sin tenant explícito, refresh, logout y rechazo 401 de refresh revocado aprobados |

El caso omitido es `MerchantOrderOptionsTest.postgresStatusCountsUseTheSameBranchScopeAsTheList`,
una comprobación opcional que requiere `merchant.test.jdbcUrl`. No forma parte de
las seis pruebas de V34, que sí se ejecutaron completas sobre PostgreSQL real.
Las dos constantes sin uso de Flutter se retiraron y se normalizó el formato
de 19 archivos, sin cambiar su lógica. Formato, análisis y pruebas se repitieron
después de esos ajustes; los tres comandos terminaron con código 0.

El JAR validado está en `.local/v34-final.jar`. Los resultados de Maven están en
`.local/v34-final.log` y `.local/v34-final-reports`; el arranque y el flujo HTTP en
`.local/v34-smoke.log` y `.local/v34-smoke-result.json`. Estos artefactos locales
están excluidos de Git. No se modificó código de aplicación después de generar
el JAR. La repetición completa del backend del 27 de septiembre quedó en
`.local/v34-release.log` y `.local/v34-release-reports`, nuevamente con BUILD SUCCESS.

Todas las bases creadas por estas ejecuciones fueron eliminadas. Se conservaron
las bases preexistentes `delivery`, `delivery_migration_data_ab1b344557` y
`delivery_migration_test_9a83c1d274ee`. El arranque utilizó servicios locales de
Compose, una base propia y notificaciones Firebase desactivadas. No envió push
ni correo a clientes y no reinició los servicios de la aplicación existente.

## Prueba de migración reproducible

### Ensayo con respaldo de la base local — aprobado el 27 de septiembre

Por indicación del usuario se utilizó `delivery` local, sin un servidor externo
de staging. La fuente estaba en V31: 62 tablas de negocio y 3.012 filas, con
9 tenants, 15 usuarios, 16 pedidos, 9 entregas y 43 notificaciones.

Se creó un respaldo PostgreSQL en formato custom y se restauró en una base con
UUID propia. Se compararon cantidades y huellas de todas las filas de las 62
tablas antes y después de restaurar. Luego se aplicaron V32, V33 y V34 con Flyway,
se validaron los checksums y se comprobó que una segunda ejecución no aplicara
migraciones adicionales.

Tras migrar se conservaron los datos originales. Las únicas diferencias
admitidas fueron las previstas por el SQL: columnas nuevas de V32/V34 y retirada
de permisos PLATFORM de roles locales en V33. Se comprobaron también los valores
NULL iniciales del outbox, las 15 identidades y membresías, las contraseñas y el
tenant de cada refresh token. El JAR arrancó con perfil `prod` sobre esa copia y
pasó las comprobaciones HTTP indicadas en la tabla de resultados.

La base fuente se volvió a comparar al finalizar: no cambió. Se eliminaron
exclusivamente la base y el contenedor temporales. Las 10 bases creadas en las
ejecuciones de cierre, incluidos los intentos de preparación y la suite, quedaron
eliminadas. Se conservaron los respaldos locales fuera de Git.

Respaldo del ensayo aprobado:
`backups/delivery-v31-rehearsal-2cab763f29b1451a935a410e95d59480.dump`.
SHA-256: `38f1c8604ded295525047c802573f435e523e935b033e3f6319b60e104fb87ec`.
La evidencia está en `.local/v34-rehearsal-result.json`,
`.local/v34-rehearsal.log` y `.local/v34-rehearsal-migrations.log`.

Este ensayo cubre PostgreSQL y la aplicación con servicios locales. No es un
respaldo de MinIO ni una prueba de DNS/TLS o de las credenciales de un servidor
productivo. No se enviaron notificaciones externas.

### Pruebas automáticas

`GlobalIdentityMigrationPostgresTest` usa Flyway y PostgreSQL real. Está desactivado
por defecto para evitar que la suite cree bases sin una conexión explícita.
Requiere una instancia de pruebas y un usuario con permiso `CREATEDB`:

```text
IDENTITY_MIGRATION_DB_USER=<usuario de pruebas>
IDENTITY_MIGRATION_DB_PASSWORD=<contraseña de pruebas>
mvn -f backend/pom.xml clean test -Didentity.migration.jdbcUrl=jdbc:postgresql://HOST:PUERTO/postgres
```

Usar JDK 21, la versión declarada por el proyecto. Cada caso crea una base
`delivery_migration_test_<UUID>`, aplica migraciones y elimina exclusivamente esa
base mediante `@AfterEach`. Si el proceso se interrumpe, los nombres creados quedan
registrados como `TEMP_DATABASE_CREATED`; cotejarlos con `TEMP_DATABASE_DROPPED`
antes de limpiar residuos. Nunca borrar bases únicamente por coincidir un prefijo.

La prueba comprueba instalación desde cero, actualización V33→V34, validación de
checksums, segunda ejecución sin migraciones pendientes, índice único parcial,
contraseñas, roles, permisos, refresh tokens y aislamiento entre tenants. Los
correos repetidos entre tenants conservan identidades y contraseñas separadas;
su inicio de sesión requiere el código de empresa. No se fusionan automáticamente.

## Antes del despliegue

1. El ensayo de restauración y migración se completó con datos de la base local,
   según la elección del usuario. Para un destino con otro volumen o esquema,
   repetirlo con su respaldo: el resultado local no mide sus tiempos de bloqueo.
2. Verificar el historial Flyway del destino. V34 debe estar pendiente; si otra
   versión de V34 ya fue aplicada, no sustituirla ni ejecutar `repair` para ocultar
   un cambio de checksum: preparar una migración posterior.
3. Crear y comprobar un respaldo recuperable. Coordinar backend y clientes: el
   backend anterior no crea `identity_id` ni `context_tenant_id`, ahora obligatorios.
   No mantener réplicas antiguas escribiendo tras la migración.
4. Ejecutar migraciones con Flyway y comprobar salud, login, refresh, permisos,
   cambio de contexto del propietario y notificación de llegada con un pedido de
   prueba del entorno. No utilizar un pedido comercial para la comprobación.
5. Ante un fallo posterior con datos escritos, aplicar una corrección compatible;
   no volver únicamente al binario anterior. Una restauración debe coordinarse con
   los datos generados después del respaldo.

Esta validación no despliega ni modifica una base productiva.

La CI ahora crea PostgreSQL 16 y activa las seis regresiones de identidad y
migración. Su comprobación de Compose incluye valores ficticios de Maps y de
ruta Firebase. La plantilla `.env.production.example` documenta la ruta del
archivo externo requerido; los secretos reales no se guardan en el repositorio.
El workflow fue revisado y sus comprobaciones se ejecutaron localmente; no se
afirma que se haya ejecutado GitHub Actions en remoto.

## Correcciones de compatibilidad

- Los bloqueos temporales migrados mantienen la membresía elegible. Mientras
  `locked_until` esté vigente, el login se rechaza; vencido el plazo, una contraseña
  correcta permite recuperar la cuenta. Los bloqueos administrativos sin plazo
  mantienen la membresía suspendida.
- El cambio de estado de usuario sincroniza la membresía dentro de la misma
  transacción. La reactivación restaura únicamente la identidad migrada exclusiva
  de ese usuario y tenant; no levanta suspensiones globales de identidades compartidas.
- Si el último contexto del propietario no corresponde a una membresía activa,
  el login vuelve a su única membresía activa. Si hay varias alternativas, exige
  seleccionar empresa.
- Los fixtures MVC registran el principal cargado desde la base, manteniendo las
  comprobaciones 401/403/200. El cierre de H2 usa JDBC directamente para evitar
  consultar advertencias sobre una conexión ya cerrada.
