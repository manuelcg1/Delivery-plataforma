# Revisión para Git y producción — 8 de noviembre de 2026

## Estado

El código y sus pruebas están preparados para revisión y commit. La publicación
en producción depende de los pasos operativos indicados abajo. Los cambios siguen
en el directorio local; esta revisión no realiza commit, push ni despliegue.

## Bloqueos corregidos durante la revisión

1. **Checkout productivo incompatible con Yape.** Compose utilizaba `CASH_ONLY`,
   mientras el APK únicamente ofrece Yape. Se añadió `MANUAL_YAPE`: registra Yape
   pendiente y admite efectivo en la API, pero rechaza métodos simulados. Ningún
   modo productivo puede ejecutar el simulador para confirmar pagos.
2. **Empresa móvil ausente en Compose productivo.** Ahora se pasa y exige
   `MOBILE_TENANT_CODE`. Debe contener el código real de una empresa activa.
3. **Caché compartida entre cuentas.** Carrito, pedidos y tracking se aíslan por
   servidor, tenant y usuario. Se descartan respuestas de sesiones anteriores,
   se purgan estas cachés al salir y se invalidan los proveedores de datos al
   cambiar de cuenta. Solo los fallos de conexión permiten lectura offline;
   errores HTTP, incluidos 401/403/500, no restauran datos almacenados.
4. **Declaración Yape interrumpida.** Se conserva un registro local por cuenta
   antes de crear el pedido. Cuando se conoce el pedido, se puede reintentar
   la declaración desde Pedidos con la misma clave, sin crear otro pedido ni
   repetir la transferencia. Una recuperación pendiente bloquea mostrar otro QR.
   Si se perdió la respuesta de creación y no se conoce el pedido, no se repite
   automáticamente el checkout: se requiere revisar pedidos y conciliar con el
   comercio. Cerrar el aviso local nunca confirma un pago. Las versiones antiguas
   del receptor no se sustituyen silenciosamente.
5. **CI Android incompleta.** La compilación de CI recibe una configuración Firebase
   sintética solo para compilar y una firma efímera. Se fija Flutter 3.41.7,
   la versión validada localmente. CI ejecutará también la prueba PostgreSQL del
   portal que antes estaba condicionada a otra propiedad.
6. **Higiene de Git y documentación.** Se excluyen APK/AAB, keystores, dumps y
   `tsbuildinfo`; se protegen archivos de entorno y contextos Docker. Se corrigió
   la documentación: debug y release comparten actualmente el applicationId,
   pero utilizan firmas diferentes.

## Evidencia de verificación

| Comprobación | Resultado |
|---|---|
| Backend con PostgreSQL e integración habilitada | 218 pruebas aprobadas, 0 fallos, 0 errores, 0 omitidas |
| Flyway | 37 migraciones validadas y ejecutadas en bases temporales; pruebas de identidad/membresías y transición V34 aprobadas |
| APK Flutter | 182 pruebas aprobadas; análisis sin incidencias; formato de CI correcto |
| Administrador | 46 pruebas aprobadas, lint sin errores, build correcto; dos avisos previos de imágenes |
| Portal del comercio | 42 pruebas aprobadas, lint y build correctos |
| Compose local y productivo | Válidos; configuración productiva comprobada con valores de prueba, no credenciales reales |
| Workflow CI | YAML válido; ejecución en GitHub pendiente del push |
| Archivos elegibles para Git | Revisión de patrones de claves privadas/tokens sin hallazgos y sin archivos mayores a 10 MB; no sustituye una auditoría exhaustiva del historial |
| Revisión de código | Identidad, aislamiento, pagos, horarios, interfaces y correcciones de caché/recuperación revisados |
| Release Android de validación | Compilado; firma efímera `CI Audit`, HTTP deshabilitado, no distribuible |

La evidencia detallada está en `.local/release-*.log`. La base PostgreSQL de
validación fue independiente de las bases reales. No se generaron pedidos ni
se cambiaron credenciales en sistemas reales.

### Compilación release Android

Se compiló correctamente un release con firma efímera y URL de staging inválida
a propósito. No es un APK para distribuir. El primer intento encontró un error TLS de Java
al descargar artefactos de Flutter; Windows confía en la raíz de inspección de
Avast. El reintento utilizó una copia local del truststore con esa raíz, sin
desactivar TLS ni modificar los certificados globales. El ajuste temporal de
Gradle quedó restaurado byte por byte y sin diff. La firma se verificó con
`apksigner`; el manifiesto declara `usesCleartextTraffic=false`. Las copias de
salida sin etiqueta se retiraron para evitar distribuir esta firma temporal.
El APK de validación está únicamente en `.local/release-audit-validation.apk`,
SHA-256 `A67D96D4D08107D93F5AB724A70CEFCC04D0775392E60F9AFB5D772BFEA0DB5A`.

El contenedor PostgreSQL temporal de esta auditoría y su volumen fueron eliminados
al completar las pruebas; los servicios y datos reales no se modificaron.

## Antes de subir a Git

- Incluir todos los archivos fuente, pruebas y migraciones nuevos, especialmente
  V32–V37 y los servicios/DTOs de identidad, Yape, horarios y acceso al comercio.
- Mantener fuera del commit `.env`, `.env.production`, `.local`, certificados,
  claves Firebase, APK/AAB y respaldos. Los ejemplos de entorno sí forman parte
  de la entrega y no contienen secretos reales.
- Crear commits verificables en una rama de entrega, revisar el diff y esperar
  la CI remota antes de integrar o etiquetar la versión. La revisión no cambia
  automáticamente la rama actual ni prepara un `git add .` indiscriminado.

## Condiciones obligatorias antes de producción

1. **Configuración real del servidor:** dominios HTTPS/WSS, CORS, cookies seguras,
   SMTP, secretos, archivo de servicio Firebase y clave Maps. Sustituir el código
   de empresa de ejemplo por el real. Estas credenciales no están verificadas por
   el Compose de prueba y deben permanecer fuera de Git.
2. **Base y archivos:** respaldo de PostgreSQL y MinIO, restauración ensayada en
   staging, revisión de la historia/checksums Flyway del servidor y migraciones
   pendientes. V34 requiere retirar los escritores del backend antiguo antes
   de aceptar escrituras con el esquema nuevo. No basta volver al binario anterior
   para revertir esa migración.
3. **Orden de despliegue:** backend/migraciones compatibles antes de los portales
   y del APK que utilizan registro móvil, disponibilidad y Yape.
4. **Firma Android definitiva:** usar la clave externa correspondiente a la app
   publicada y un versionCode superior al ya distribuido. El APK de dominio
   generado anteriormente es debug y anterior a estas correcciones; debe
   reemplazarse por una compilación nueva. La clave efímera de CI no sirve para
   actualizar usuarios ni para publicar en la tienda.
5. **Prueba real controlada en staging:** registro de cliente con teléfono,
   repartidor pendiente/activación, acceso aislado al comercio, edición de datos e
   imágenes, horarios cerrados y nocturnos, pedido Yape pendiente y recuperación
   de declaración interrumpida. Conciliar la transferencia con el comercio;
   ninguna declaración equivale a confirmación bancaria automática.

La aprobación final de producción requiere completar estas condiciones y la CI
del commit concreto que se vaya a desplegar.

## Corrección del primer resultado de CI

En el commit `2d6fc2c5`, ambos eventos (push y pull_request) pasaron backend,
administrador, portal y configuración. El trabajo móvil pasó formato, análisis y
pruebas, pero falló al compilar release con `What went wrong: 25.0.5`.

El trabajo Android no fijaba el JDK y utilizó Java 25, incompatible con el wrapper
Gradle 8.14. Se añadió `actions/setup-java` con Temurin 21 y se indica explícitamente
a Flutter usar `$JAVA_HOME`, también para la firma efímera y la compilación. Es el
JDK utilizado en la validación local satisfactoria del release.

Referencia: [matriz oficial Java/Gradle](https://docs.gradle.org/current/userguide/compatibility.html#java).
Debe subirse esta corrección a la misma rama y comprobar el nuevo resultado de CI;
el resultado anterior no cambia hasta ejecutar el workflow del nuevo commit.
