# Flutter conserva automáticamente sus clases de embedding. Estas reglas protegen
# los plugins que acceden a modelos por reflexión en builds minificados.
-keepattributes Signature,*Annotation*
-keep class io.flutter.plugins.** { *; }
-dontwarn javax.annotation.**
