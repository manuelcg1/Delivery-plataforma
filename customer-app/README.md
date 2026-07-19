# Customer Mobile App v0.7

Aplicación Flutter para clientes finales. Implementa un flujo conectado al backend: registro e inicio de sesión, sesión segura, direcciones, descubrimiento de comercios, catálogo, carrito, checkout idempotente, pago simulado, pedidos y tracking.

## Requisitos y ejecución

- Flutter estable con Dart 3.4 o superior.
- Android Studio/SDK para Android; Xcode para iOS.
- Backend disponible.

```powershell
flutter create . --platforms=android,ios
flutter pub get
flutter run --dart-define=ENVIRONMENT=development --dart-define=API_BASE_URL=http://10.0.2.2:8080 --dart-define=WS_BASE_URL=ws://10.0.2.2:8080
```

Para dispositivo físico use la IP local del equipo en `API_BASE_URL`. Staging y producción deben usar HTTPS/WSS.

## Seguridad y ambientes

Variables admitidas: `ENVIRONMENT`, `API_BASE_URL`, `WS_BASE_URL`, `MAP_PROVIDER`, `MAP_API_KEY`, `SENTRY_DSN`, `FIREBASE_ENABLED`. No se incluyen claves reales. Los tokens se guardan en `flutter_secure_storage`; el cliente agrega Bearer y correlation ID, renueva una sola vez ante 401 y limpia la sesión si falla.

## Verificación

```powershell
dart format --set-exit-if-changed .
flutter analyze
flutter test
flutter build apk --debug
```

## Android debug

La variante debug no necesita certificado propio, se instala como una aplicación
independiente (`com.delivery.platform.customer.debug`) y permite HTTP para probar
contra el backend local.

Con el backend publicado en el puerto `8080`, desde un emulador Android basta con:

```powershell
flutter build apk --debug
```

Ese comando utiliza por defecto `http://10.0.2.2:8080` y
`ws://10.0.2.2:8080`. Para un dispositivo físico, use la IP LAN del equipo:

```powershell
.\scripts\build-debug.ps1 -ApiBaseUrl http://192.168.1.10:8080 -WsBaseUrl ws://192.168.1.10:8080
```

El archivo generado queda en `build/app/outputs/flutter-apk/app-debug.apk`.
La computadora y el teléfono deben estar en la misma red y el firewall debe
permitir conexiones al puerto del backend.

## Android release

El identificador definitivo es `com.delivery.platform.customer`. Release bloquea tráfico HTTP, activa R8/minificación y exige una firma externa; nunca utiliza la clave debug.

1. Crear una upload key fuera del repositorio:

```powershell
keytool -genkeypair -v -keystore C:\secure\delivery-customer-upload.jks -alias delivery-customer-upload -keyalg RSA -keysize 2048 -validity 10000
Copy-Item android\key.properties.example android\key.properties
```

2. Completar `android/key.properties`, o definir en CI:

- `DELIVERY_ANDROID_STORE_FILE`
- `DELIVERY_ANDROID_STORE_PASSWORD`
- `DELIVERY_ANDROID_KEY_ALIAS`
- `DELIVERY_ANDROID_KEY_PASSWORD`

3. Generar un APK o App Bundle firmado:

```powershell
.\scripts\build-release.ps1 -Environment production -ApiBaseUrl https://api.example.com -WsBaseUrl wss://api.example.com
.\scripts\build-release.ps1 -Environment production -ApiBaseUrl https://api.example.com -WsBaseUrl wss://api.example.com -AppBundle
```

Con las variables configuradas también puede ejecutarse directamente:

```powershell
flutter build apk --release --dart-define=ENVIRONMENT=production --dart-define=API_BASE_URL=https://api.example.com --dart-define=WS_BASE_URL=wss://api.example.com
```

El APK queda en `build/app/outputs/flutter-apk/app-release.apk`; el AAB en `build/app/outputs/bundle/release/app-release.aab`. Antes de publicar, incrementar `version` en `pubspec.yaml` y conservar de forma segura la upload key.

Si Gradle muestra `PKIX path building failed`, importe el certificado raíz corporativo en el truststore del JDK usado por Flutter/Gradle. No desactive la validación TLS.

iOS requiere macOS, certificados y perfiles fuera del repositorio. Push, mapas, analytics y crash reporting quedan desacoplados para conectar proveedores reales sin guardar secretos.
