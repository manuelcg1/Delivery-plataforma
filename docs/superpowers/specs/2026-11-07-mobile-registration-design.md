# Acceso móvil sin código de empresa

Solicitud: quitar código de empresa de registro/login del APK; registrar teléfono/WhatsApp obligatorio y elegir Cliente o Repartidor. La empresa del administrador actual es 123456789. El usuario confirmó que repartidores requieren activación administrativa antes de operar.

El servidor configura MOBILE_TENANT_CODE; el APK no envía tenantCode para acceso móvil. No elegir primer tenant ni permitir tenant libre cliente. Mantener login administrativo y APIs legadas de otros clientes. Login-mobile resuelve exclusivamente empresa configurada e ignora/rechaza intentos de seleccionar otra. Fail closed si falta configuración o tenant inactivo.

Nuevo POST /api/v1/auth/register-mobile público con {firstName,lastName,email,password,phone,profile:"CUSTOMER"|"COURIER"}. No acepta rol administrativo ni tenant. Teléfono peruano requerido: 9 dígitos iniciando 9 o +51 seguido de esos 9 dígitos; normalizar a +51XXXXXXXXX después de retirar espacios/guiones/paréntesis. Persistir en users.phone, campo nullable ya existente desde Flyway V3; no cambiar esquema ni inventar teléfonos a cuentas previas. Validar servidor/cliente.

CUSTOMER: crea usuario/membresía/rol CUSTOMER, respuesta móvil existente con tokens y user. COURIER: crea usuario/membresía/rol COURIER y courier_profiles INACTIVE, vehicle_type OTHER y mismo teléfono; no emite sesión operativa. Respuesta {pendingApproval:true,message:"Tu cuenta de repartidor está pendiente de activación por el administrador."}. Cliente muestra éxito de registro y vuelve/permanece en login. Login móvil comprueba contraseña antes de devolver COURIER_PENDING_APPROVAL si perfil no activo; al activarse vía gestión existente permite entrar. No confiar status ni permisos enviados por cliente.

Login-mobile usa email/password y empresa servidor; endpoint administrativo /login conserva su contexto y formularios. Endpoints legacy/register-customer, cookies, refresh y contraseñas existentes conservan compatibilidad. No migrar usuarios entre empresas ni cambiar credenciales.

Portal comercios: añadir customerPhone nullable al OrderRow (listado y detalle) obtenido de users.phone con join de tenant y usuario del pedido; mantener OrderDetail.phone como contacto de entrega. Mostrar teléfono de cuenta bajo nombre de cliente y en detalle con etiquetas distintas, sin inventar teléfono a cuentas previas. Solo pedidos autorizados al comercio y tenant actuales.

Arquitectura: extender identidad móvil mediante DTO/servicio y migración; formulario Flutter existente accesible y con paleta actual; pequeño componente de contacto del cliente en portal. No duplicar identidad global ni tocar reglas Yape/seguimiento/asignación existentes.
