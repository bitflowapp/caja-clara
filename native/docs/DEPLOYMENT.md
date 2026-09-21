# Instalación y despliegue

## Aplicación Windows

Descomprimir íntegramente el paquete `CajaClara-Native-Windows-x64`. Ejecutar `Instalar Caja Clara.cmd`. El script instala por usuario bajo `%LOCALAPPDATA%\Programs\LUNA\CajaClaraNative\0.2.0`, crea accesos directos y no requiere privilegios de administrador. No copiar solo `CajaClara.exe`: necesita las bibliotecas y el índice de recursos `.pri` de su carpeta.

También se puede ejecutar `app\CajaClara.exe` directamente. El paquete publicado contiene el runtime de .NET y Windows App SDK. Arquitectura x64. El proyecto declara un mínimo de Windows 10 build 19041; las pruebas automatizadas se realizan en el runner Windows indicado por los logs, no en todas las ediciones y escalas DPI soportadas por el manifiesto.

Primera ejecución: nombre del comercio, nombre del dueño, usuario y contraseña de al menos doce caracteres. No hay cuenta de demostración predeterminada. `CajaClara.exe --demo` abre un directorio separado, inicialmente vacío, y marca los comprobantes como prueba.

Datos reales: `%LOCALAPPDATA%\LUNA\CajaClaraNative\Business`. Datos de prueba: carpeta hermana `Demo`. El programa anterior Flutter no se modifica.

Antes de actualizar, cerrar la app y guardar un respaldo. Las versiones de la aplicación se instalan fuera de la carpeta de datos. `Uninstall.ps1` elimina programa y accesos directos, pero conserva bases, configuración y respaldos. Falta firma comercial Authenticode; no se declara un instalador MSI/MSIX firmado.

## Servidor y teléfono

El paquete incluye `server\CajaClara.Backend.exe`; el repositorio incluye la misma aplicación ASP.NET Core compilable para otros hosts compatibles. Su directorio de trabajo debe contener `wwwroot`.

Preparación local en PowerShell, desde la carpeta `server`:

```powershell
$env:CAJACLARA_DATA_DIR = Join-Path $env:LOCALAPPDATA 'LUNA\CajaClaraCloud'
.\CajaClara.Backend.exe --init
```

La terminal solicita datos de comercio y credenciales nuevas del dueño sin mostrar la contraseña. Para una prueba **solo en la misma PC**:

```powershell
$env:ASPNETCORE_ENVIRONMENT = 'Development'
.\CajaClara.Backend.exe --urls 'http://127.0.0.1:5189'
```

Abrir `http://127.0.0.1:5189`, iniciar sesión, generar un código en Equipos y vincular desde Windows con esa URL. `localhost` o `127.0.0.1` en el celular apuntan al propio celular, no a la PC: no sirven como enlace remoto entre equipos.

Para acceso desde el teléfono o Internet, desplegar el servidor en un host estable con un dominio HTTPS, almacenamiento persistente y respaldos. Configurar `ASPNETCORE_ENVIRONMENT=Production`. Terminar TLS en el servidor o en un proxy conocido, y establecer `CAJACLARA_TRUSTED_PROXY` con la IP exacta del proxy cuando corresponda. No abrir el puerto SQLite ni usar `Development` como bypass de HTTPS en Internet.

Los valores de dominio, certificado TLS y acceso al hosting no se inventaron ni se desplegaron automáticamente. La entrega contiene el servidor, no un servicio público ya operativo. La cuenta cloud es independiente del usuario local; ambas usan credenciales elegidas por el dueño.

## Operación del host

Ejecutar una sola instancia con permisos de usuario de servicio limitados. Conservar `cloud.sqlite`, WAL y directorio `keys`; respaldarlos mediante un procedimiento consistente con SQLite y cifrar/proteger el volumen. La app Windows tiene backup local automático; el servidor no incluye un servicio programado de backup cloud.

Configurar supervisión y reinicio del proceso, logs sin secretos, cuotas, alertas de disco y monitoreo de `/health`. `/health` confirma que el proceso responde; no certifica sincronización, pagos o servicios fiscales. El endpoint no requiere sesión y no expone datos del comercio.

El panel seguirá mostrando lo último sincronizado cuando la PC esté apagada. Para aplicar comandos, la PC y el cliente de sincronización deben volver a ejecutarse.
