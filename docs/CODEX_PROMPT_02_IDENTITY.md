Implementa la fase v0.2 Identity en este repositorio.

Objetivos:
1. Registro transaccional de un tenant y su administrador principal.
2. Inicio de sesión con correo y contraseña.
3. JWT de acceso y refresh token rotativo.
4. BCrypt para contraseñas.
5. Roles y permisos por tenant.
6. Auditoría de acceso y cambios relevantes.
7. Aislamiento multicliente obligatorio.
8. DTOs y validación Bean Validation.
9. Manejo uniforme de errores.
10. Pruebas unitarias y de integración con Testcontainers.

Restricciones:
- No confiar en tenant_id enviado por el frontend después de iniciar sesión.
- No exponer entidades JPA.
- Mantener monolito modular.
- Crear migraciones Flyway incrementales.
- Documentar endpoints y ejemplos en README.
