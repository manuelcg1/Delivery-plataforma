# Auditoría de preparación del APK — 2026-09-08

Alcance: configuración Android, conexión al backend local, revisión de los cambios locales del catálogo y verificaciones automatizadas. No constituye una auditoría exhaustiva de seguridad ni una prueba completa de compra.

## Configuración verificada

- Equipo por Wi-Fi: `192.168.1.107`.
- API del APK: `http://192.168.1.107:8080`.
- WebSocket: `ws://192.168.1.107:8080/api/v1/realtime`.
- Dispositivo USB autorizado: OPPO CPH2531; Wi-Fi `192.168.1.108`.
- Ping desde el teléfono al equipo: 2 respuestas de 2 paquetes.
- Backend local: `/actuator/health` responde `UP` tras iniciar backend, PostgreSQL, Redis, MinIO y Mailpit.
- Variante debug permite HTTP; manifiesto principal bloquea HTTP y deshabilita backups.

## Verificaciones

- `flutter analyze`: sin incidencias.
- `flutter test --no-pub`: 102 pruebas aprobadas.
- `mvn clean test` con Java 21: 101 pruebas aprobadas, sin errores ni omisiones.
- `npm run lint` en admin-web: aprobado con 2 advertencias sobre elementos `img`.
- `npm run build` en admin-web: aprobado; advertencias CSS sobre `end` y optimización de imágenes.
- `docker compose config --quiet`: aprobado.

Maven inicialmente utilizaba Java 17. Después de seleccionar Java 21, fue necesario recompilar desde cero para eliminar clases de pruebas antiguas que impedían el descubrimiento de JUnit.

## Hallazgos pendientes

1. **Rendimiento del buscador:** `MerchantPage` crea la petición `products()` dentro de `build`; cada `setState` al escribir vuelve a consultar el catálogo y muestra el indicador de carga. Conviene conservar el Future y aplicar el filtro local sin nuevas solicitudes por cada tecla.
2. **Documentación Android desactualizada:** el README indica que debug usa `com.delivery.platform.customer.debug`, pero Gradle utiliza `com.delivery.platform.customer` también en debug. La instalación actualiza la app existente si la firma coincide.
3. **Dependencia de correo para healthcheck:** iniciar únicamente `backend` no inicia Mailpit, que no figura en `depends_on`. El healthcheck queda degradado hasta iniciar el correo local.
4. **Red local:** la IP Wi-Fi puede cambiar por DHCP. El teléfono necesita acceso a esa red para usar este APK; el USB por sí solo no proporciona acceso a la IP LAN.

Se conservaron los cambios locales existentes. No se modificaron entidades, reglas de tenant, esquema ni credenciales.

## APK e instalación

- `flutter build apk --debug --no-pub` con las URLs anteriores: aprobado.
- Archivo: `customer-app/build/app/outputs/flutter-apk/app-debug.apk`, 191927569 bytes.
- `adb install -r`: `Success`.
- `adb shell am start -W -n com.delivery.platform.customer/.MainActivity`: `Status: ok`, arranque en frío, 4494 ms.
- La comprobación adicional de proceso/logcat no se ejecutó porque se rechazó su permiso. No se verificó un flujo autenticado completo en el dispositivo.
