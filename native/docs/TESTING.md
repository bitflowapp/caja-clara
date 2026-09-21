# Pruebas y evidencia

El workflow relevante es **Caja Clara Native**. El workflow antiguo **Caja Clara CI** sigue perteneciendo a Flutter; sus resultados no prueban ni invalidan por sí mismos esta edición.

## Suites

```powershell
dotnet run --project native/tests/CajaClara.Tests/CajaClara.Tests.csproj -c Release -- native/artifacts
dotnet run --project native/tests/CajaClara.CloudTests/CajaClara.CloudTests.csproj -c Release -- native/artifacts
python native/tests/ui_smoke.py
python native/tests/browser_e2e.py
```

Las pruebas nativas y de navegador requieren primero publicar app/terminal y compilar backend en las carpetas del workflow. Las dependencias de prueba son pywinauto, Pillow y Playwright con Chromium.

## Núcleo

Cálculos exactos, IVA incluido, descuentos, unidades fraccionadas, precios obsoletos, stock insuficiente, pagos combinados, vuelto, referencias electrónicas, contraseñas/PIN/lockout, permisos no falsificables, revocación, stock con ledger, caja, ventas transaccionales e idempotentes, rollback, reapertura, cola fiscal sin CAE, devolución compensatoria, compras, outbox, comandos, backups y exportación PDF/XLSX.

## Cloud

Cuentas, bloqueo, códigos de vinculación de un uso, rotación y revocación, una caja primaria, aislamiento entre comercios, ingestión repetida, validación de hash/equipo, conflictos de versión, comandos idempotentes y resultado final inmutable, conciliación de métricas de devoluciones.

## End-to-end real

El navegador no intercepta ni simula rutas de negocio. Usa backend ASP.NET Core real, SQLite real y el CLI publicado. Crea una venta por terminal, sincroniza por HTTP, verifica que aparece en el panel; cambia un precio desde el panel, recibe el comando en la base local y confirma el resultado remoto. También comprueba CSRF, autenticación, revocación, cierre solicitado no forzado, ausencia de errores JavaScript y overflow horizontal en viewport móvil/escritorio.

`ui_smoke.py` ejecuta el binario WinUI, opera controles nativos y verifica efectos en SQLite. Si la ventana no aparece, el flujo falla aunque el ejecutable compile. Se conservan capturas, árbol de accesibilidad y diagnóstico de proceso/recursos/eventos cuando corresponda.

## Artefactos

El ZIP de evidencia contiene `source-commit.txt`, logs de compilación y archivos `*-test-results.json`. Esos JSON son la fuente de verdad para cantidades y resultados de **esa ejecución**. La presencia del ZIP del programa no implica que todas las pruebas hayan pasado; los artefactos se suben también cuando hay fallos para permitir diagnóstico.

Los nombres de comercios y ventas en capturas corresponden a **fixtures aisladas de QA**, no a ventas reales del usuario. Las contraseñas se generan aleatoriamente por ejecución; no se publican credenciales de fixture. No existen fixtures activadas en el comercio real por defecto.

## No certificado

No se probaron emisión fiscal ARCA, pagos/capturas/reembolsos productivos, impresión física, lector físico, corte eléctrico real, todas las escalas DPI, todas las versiones de Windows, Safari/iPhone físico, restauración con escritores concurrentes, carga prolongada ni seguridad independiente. Estas áreas no deben marcarse PASS por haber pasado una prueba del núcleo.
