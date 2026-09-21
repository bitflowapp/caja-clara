# Caja Clara Native 0.2.0

Edición Windows nativa de Caja Clara: C#/.NET 10, WinUI 3, SQLite local, terminal y panel del dueño. **Esta entrega no está autorizada para producción fiscal ni cobros integrados.**

El proyecto Flutter original permanece intacto. Todo el desarrollo nuevo está en `native/`, en la rama `work/caja-clara-native-20260921`. Las bases Hive, licencias y archivos del producto anterior no se migran ni se modifican automáticamente.

## Qué se puede operar

El programa Windows permite crear el comercio y su dueño, cargar productos y stock, abrir caja, buscar/escanear códigos mediante teclado, registrar ventas y pagos combinados, calcular vuelto, registrar movimientos, cerrar turnos, ingresar compras y proveedores, registrar devoluciones totales, administrar usuarios/PIN y obtener reportes, respaldos, PDF y XLSX.

El panel del dueño usa una API real. Recibe ventas sincronizadas, muestra el último contacto del equipo, solicita cambios de precio y disponibilidad, y envía solicitudes de cierre. Una solicitud pendiente **no equivale a una acción aplicada**. El equipo confirma cada resultado.

## Límites que no deben confundirse con funciones terminadas

- **ARCA:** existe la cola de solicitudes fiscales; no están implementadas la autenticación WSAA, emisión WSFE, notas fiscales ni el PDF fiscal con CAE/QR. No alcanza con ingresar un certificado para habilitarla.
- **Mercado Pago:** los cobros electrónicos se registran manualmente como `MANUAL_UNVERIFIED`. No están implementados OAuth, QR dinámico, Point, webhooks ni conciliación automática. No se debitan fondos desde esta versión.
- **Impresión:** existe impresión nativa mediante el controlador de Windows. La salida física en impresoras 58/80 mm requiere prueba con el hardware concreto.
- **Multicaja:** una caja primaria por comercio. Las identificaciones y los eventos están preparados para evolución, pero el servidor rechaza una segunda caja activa hasta resolver coordinación de stock y conflictos.
- **Internet público:** se incluye el servidor, no un servicio cloud ya desplegado. Para usar el teléfono fuera de la PC hace falta desplegarlo con HTTPS y almacenamiento persistente.
- **Restauración:** disponible por terminal con copia previa y desvinculación remota. Antes de reconectar un historial restaurado hay que conciliar sus eventos con el servidor.

## Abrir en Windows

Descomprimir el paquete completo. Ejecutar `Instalar Caja Clara.cmd`, o `app/CajaClara.exe` para abrirlo sin instalar. No copiar solamente el ejecutable: necesita las bibliotecas y recursos incluidos.

No se necesita instalar el SDK para utilizar el paquete publicado. La primera ejecución solicita el nombre del comercio, el dueño, un usuario y una contraseña de al menos doce caracteres. **No hay credenciales predeterminadas.**

Datos de trabajo: `%LOCALAPPDATA%\LUNA\CajaClaraNative\Business`.

Modo aislado para pruebas: `CajaClara.exe --demo`; datos en la carpeta hermana `Demo`. Empieza vacío y marca sus comprobantes como demostración. No crea automáticamente ventas, productos ni usuarios ficticios en el comercio real.

## Compilar

En Windows con el SDK fijado por `global.json`:

```powershell
dotnet build native/src/CajaClara.Core/CajaClara.Core.csproj -c Release
dotnet publish native/src/CajaClara.Windows/CajaClara.Windows.csproj -c Release -r win-x64 --self-contained true -o native/artifacts/package/app
dotnet publish native/src/CajaClara.Cli/CajaClara.Cli.csproj -c Release -r win-x64 --self-contained true -o native/artifacts/package/terminal
dotnet publish native/src/CajaClara.Backend/CajaClara.Backend.csproj -c Release -r win-x64 --self-contained true -o native/artifacts/package/server
```

Las pruebas, registros de compilación y capturas reales se guardan en el artefacto `CajaClara-Native-source-and-evidence` de GitHub Actions. Consultar `docs/TESTING.md`: no confundir el CI de Flutter con el workflow nuevo `Caja Clara Native`.

## Documentación

- `docs/ARCHITECTURE.md`: límites y decisiones de arquitectura.
- `docs/SECURITY.md`: permisos, secretos, sesiones y amenazas pendientes.
- `docs/DATABASE.md`: transacciones, registros y migraciones.
- `docs/SYNC.md`: outbox y reconciliación.
- `docs/REMOTE_CONTROL.md`: vinculación y comandos.
- `docs/DEPLOYMENT.md`: programa, servidor y actualización.
- `docs/TERMINAL.md`: contratos JSON de la terminal.
- `docs/FISCAL.md` y `docs/MERCADOPAGO.md`: estado real de las integraciones.
- `docs/TESTING.md`: ejecución y evidencia verificable.
