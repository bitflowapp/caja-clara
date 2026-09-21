# Seguridad

## Controles implementados

Autenticación local y remota con PBKDF2-HMAC-SHA256, sal aleatoria de 16 bytes, 600.000 iteraciones y comparación en tiempo constante. Contraseñas de 12 a 256 caracteres. Cinco intentos inválidos bloquean temporalmente durante quince minutos. El PIN local tiene seis dígitos y también usa hash y bloqueo. No hay contraseña maestra ni credenciales predeterminadas.

El núcleo vuelve a consultar el rol y estado del usuario antes de operar: cambiar un botón o fabricar un `Actor` con rol Owner no concede privilegios. Los comandos remotos están limitados a una lista cerrada, identifican comercio/equipo y tienen vencimiento y versión esperada. Nunca aceptan PowerShell, rutas ejecutables ni scripts arbitrarios.

La PWA usa cookies HttpOnly, SameSite=Strict y expiración fija de ocho horas. En producción son Secure con prefijo `__Host-`. Toda escritura de sesión/dueño valida antiforgery `X-CSRF-TOKEN`. Se revisa usuario activo y versión de sesión en cada petición autenticada. No se guardan tokens de sesión en localStorage.

Vinculación de equipo: código aleatorio de 128 bits, un uso, cinco minutos. Token posterior aleatorio de 256 bits, hash en servidor, protegido con DPAPI CurrentUser en Windows, revocable y con vencimiento de noventa días. Nunca se imprime en logs.

HTTPS obligatorio en producción; HTTP solo para desarrollo loopback. El proxy de confianza se configura por IP, no con comodines. API con `Cache-Control: no-store`, CSP restrictiva, sin framing ni CORS abierto. Service worker solo cachea archivos públicos del panel, nunca respuestas `/api`.

Consultas SQL parametrizadas, validación de tamaño de petición, límites por IP para credenciales/dispositivos, auditoría comercial y de comandos. No se registran contraseñas, PIN, tokens ni certificados completos.

## Fronteras y riesgos pendientes

Estos controles **no equivalen a una auditoría de seguridad completa ni a certificación comercial**. Las pruebas cubren permisos, aislamiento entre cuentas, CSRF, revocación y reintentos; no sustituyen pentest, carga, análisis de dependencias o revisión independiente.

La base SQLite local no usa cifrado de aplicación. Un administrador del equipo puede leerla o modificarla. Se requiere una cuenta Windows por operador o una política de acceso al equipo, permisos NTFS y cifrado de disco. La auditoría no es un registro criptográficamente inalterable frente al administrador del host.

La cuenta móvil no tiene MFA/WebAuthn, recuperación de contraseña ni gestión de sesiones individuales. Falta expiración por inactividad en el escritorio. No vender estos controles como presentes.

Las claves de ASP.NET Data Protection se persisten. En Windows se protegen con DPAPI; en Linux, este proyecto no agrega cifrado propio de ese directorio. Proteger el volumen y permisos del servicio y respaldar las claves de forma segura.

La revocación de equipo impide nuevas solicitudes autenticadas, pero no revoca mágicamente un comando que la PC ya recibió ni desactiva una caja que está vendiendo sin Internet. El panel explica este límite.

El instalador y ejecutable no tienen firma comercial Authenticode. Se debe firmar la distribución definitiva y probar SmartScreen/antivirus, sin instruir al cliente a desactivar protecciones globales.

ARCA y Mercado Pago no están conectados; no se recibieron ni copiaron secretos productivos de esos servicios.
