# Arquitectura y alcance

## Componentes existentes

`CajaClara.Core` contiene dominio, reglas comerciales, autenticación local, persistencia SQLite, reportes, outbox y ejecución de comandos. `CajaClara.Windows` es una aplicación WinUI 3 sin WebView, con MVVM para sesión y carrito, inyección de dependencias y controles nativos. `CajaClara.Cli` utiliza exactamente los mismos servicios comerciales. `CajaClara.Backend` es una API ASP.NET Core y sirve la PWA del dueño desde `wwwroot`.

```text
WinUI / Terminal → servicios de aplicación → transacción SQLite
                                            ├── registros y movimientos
                                            ├── auditoría
                                            └── outbox
                                                   ↓ HTTPS saliente
                                            API → proyecciones remotas
                                                   ↕ cookie + CSRF
                                             Panel del dueño
                                                   ↓ comandos tipados
                                             Equipo autorizado
```

La venta se confirma primero en la base local. El servidor no es requisito para efectivo o registro manual de cobros. La sincronización es eventual; el panel muestra el último contacto, nunca afirma que una PC desconectada esté actualizada.

## Decisiones explícitas

Dinero en centavos enteros `long`; cantidades en milésimas. Extensiones de precio usan `decimal` y redondeo explícito, no `double`. Precios y costos quedan fotografiados en las líneas de la venta. Los reportes de margen no pretenden calcular ganancia contable neta.

Cada comando y venta usa UUID y control de reintentos. Toda mutación comercial y su outbox se confirma en una transacción. Movimientos de stock, caja, compras, devoluciones y auditoría son inmutables desde los servicios. Las correcciones se representan mediante operaciones compensatorias.

La versión 0.2.0 admite un comercio por instalación local y **una caja primaria activa por cuenta remota**. No simula coordinación de stock entre cajas desconectadas. El servidor SQLite es para una instancia; requiere migración explícita para PostgreSQL y escalado horizontal.

## Alcance todavía no completado

No hay integración operativa ARCA ni Mercado Pago: ver sus documentos específicos. No hay autorizaciones remotas de descuentos/devoluciones, devolución parcial, conciliación bancaria automática, cuenta corriente con pagos posteriores a proveedores, restauración guiada, MFA móvil ni migración del producto Flutter.

La interfaz carga instantáneas completas del catálogo e historial. No se ha certificado rendimiento con millones de registros. Antes de vender esta edición como sistema de gran escala, paginar consultas e incorporar pruebas de carga. Los permisos y contratos están separados de la presentación, pero varios formularios se construyen en código WinUI; no se afirma que toda la vista esté expresada en XAML.

## Producto existente

Se preserva el proyecto Flutter en la raíz del repositorio. Los datos nuevos viven en `LUNA/CajaClaraNative`; nunca se abre la base Hive anterior como SQLite ni se reemplazan sus archivos.
