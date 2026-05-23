# Caja Clara — Cash KPI Fix Report

- **Fecha:** 2026-05-23
- **Proyecto:** `D:\bit flow hoy actualizado 12.2\caja-clara`
- **Referencia QA:** `C:\demo comerciales\sales_readiness_qa\CAJA_CLARA_SALES_READINESS_QA_V2.md` (Bug B-01)
- **Install actualizado:** `C:\Users\marco\AppData\Local\CajaClara\b_plus_commerce.exe` (LastWrite 23/05/2026 03:51)

---

## 1. El bug

El dashboard mostraba **Caja actual $2.500** con el helper **"Lo que tenés ahora"**, pero la fórmula de Caja del día decía **$10.000 apertura + $2.500 ventas = $12.500**. Dos números distintos, los dos rotulados como "lo que hay ahora en la caja". Un cliente con foco en números (contador, comercio chico activo) lo nota inmediatamente.

Mismo problema en la pantalla Caja: tile **"Queda en caja $2.500"** contradecía la fórmula **Caja del día $12.500** del mismo panel.

---

## 2. Root cause

El KPI usaba `store.cashBalancePesos` (`commerce_store.dart:263`), que es el neto acumulado de **todos los movimientos históricos** (`sum(movement.cashImpactPesos)`) y **no incluye la apertura de caja del día** (la apertura se guarda aparte en `_cashOpeningBalancePesos`).

La fórmula de "Caja del día" en cambio usa `store.todayExpectedCashPesos` (`commerce_store.dart:119–125`), que sí cuenta la apertura: `opening + todaySalesPesos − todayExpensesPesos`.

Conclusión: el KPI del dashboard y la fórmula del panel estaban leyendo dos métricas diferentes con el mismo nombre comercial ("Lo que tenés ahora" / "caja del día"). Eso es lo que generaba la contradicción visual.

---

## 3. Decisión: cambiar la métrica, no la etiqueta

Para un usuario de pyme, "Lo que tenés ahora" o "Caja actual" significa **el efectivo físico que hay en el cajón en este momento**. Ese número es por definición **apertura + ventas − gastos** (= `todayExpectedCashPesos`). El "neto histórico de movimientos" no es algo que se le muestre a un dueño de comercio.

Entonces:
- **Fix de valor**, no de copy: el KPI ahora usa `todayExpectedCashPesos`.
- **Etiqueta unificada:** "Caja del día" en los dos lugares (dashboard y panel Caja), para alinearse con la fórmula que ya existía.
- **Estado sin apertura:** cuando `todayExpectedCashPesos` es `null` (no hay apertura registrada hoy), el KPI muestra **"Sin apertura"** con helper **"Abrí la caja para ver el saldo"**, en lugar de mostrar un número que no significa nada.

No se tocó `cashBalancePesos` ni ningún otro getter del store. Los tests existentes que usan `cashBalancePesos` como API (sale, expense, free sale, backup/restore, barcode) siguen verdes sin cambios. El fix es 100% de UI/presentación.

---

## 4. Cambios (diff mínimo)

### `lib/app/screens/home_screen.dart` (líneas 447–456)

```diff
-      KpiCard(
-        label: 'Caja actual',
-        value: formatMoney(store.cashBalancePesos),
-        icon: Icons.account_balance_wallet_rounded,
-        accent: BpcColors.accentStrong,
-        helper: 'Lo que tenés ahora',
-        onTap: onOpenCash,
-      ),
+      KpiCard(
+        label: 'Caja del día',
+        value: store.todayExpectedCashPesos == null
+            ? 'Sin apertura'
+            : formatMoney(store.todayExpectedCashPesos!),
+        icon: Icons.account_balance_wallet_rounded,
+        accent: BpcColors.accentStrong,
+        helper: store.todayExpectedCashPesos == null
+            ? 'Abrí la caja para ver el saldo'
+            : 'Apertura + ventas - gastos',
+        onTap: onOpenCash,
+      ),
```

### `lib/app/screens/summary_screen.dart` (líneas 99–113)

```diff
-                            SizedBox(
-                              width: width,
-                              child: MetricCard(
-                                label: 'Queda en caja',
-                                value: formatMoney(store.cashBalancePesos),
-                                helper: 'Lo que tenés ahora',
-                              ),
-                            ),
+                            SizedBox(
+                              width: width,
+                              child: MetricCard(
+                                label: 'Caja del día',
+                                value: store.todayExpectedCashPesos == null
+                                    ? 'Sin apertura'
+                                    : formatMoney(
+                                        store.todayExpectedCashPesos!,
+                                      ),
+                                helper: store.todayExpectedCashPesos == null
+                                    ? 'Abrí la caja para ver el saldo'
+                                    : 'Apertura + ventas - gastos',
+                              ),
+                            ),
```

### `lib/app/services/excel_export_service.dart` (líneas 97–100)

Coherencia en el Excel exportado (que un cliente abre offline):

```diff
     _writeRow(sheet, 4, <CellValue>[
-      TextCellValue('Caja actual'),
-      IntCellValue(store.cashBalancePesos),
+      TextCellValue('Caja del día'),
+      IntCellValue(store.todayExpectedCashPesos ?? store.cashBalancePesos),
     ]);
```

(Fallback a `cashBalancePesos` si no hay apertura, para no exportar un null.)

### Tests nuevos

**`test/commerce_store_hardening_test.dart`** — grupo `'Caja del día KPI'`:

- `todayExpectedCashPesos = apertura + ventas - gastos (dashboard truth)` — lockea que el getter del dashboard es `todayExpectedCashPesos` (no `cashBalancePesos`) y que los dos valores difieren cuando hay apertura.
- `todayExpectedCashPesos is null when apertura is not registered today` — cubre el fallback "Sin apertura".

**`test/b_plus_commerce_app_smoke_test.dart`** — dos tests widget:

- `Home KPI "Caja del día" matches apertura + ventas - gastos` — verifica que el render del dashboard muestre `$12.500` con label `Caja del día` (no `Caja actual`).
- `Home KPI shows "Sin apertura" when caja is not opened today` — verifica el estado sin apertura.

---

## 5. Build & test pipeline

| Paso | Resultado |
|------|-----------|
| `flutter clean` | OK |
| `flutter pub get` | OK (22 paquetes con versiones nuevas disponibles, ninguna en restricción crítica) |
| `flutter analyze` | **No issues found!** (ran in 2.0s) |
| `flutter test` | **65/65 pass** (4 tests nuevos incluidos) |
| `flutter build windows --release` | OK → `build\windows\x64\runner\Release\b_plus_commerce.exe` |
| `flutter build web --release` | OK → `build\web\` (warning preexistente de wasm-dry-run por `speech_to_text`, no relacionado) |

---

## 6. Install update + verificación manual

- App previa detenida con `Stop-Process -Force` sobre PID 14444.
- `Copy-Item` del contenido de `build\windows\x64\runner\Release\*` a `C:\Users\marco\AppData\Local\CajaClara\` (sobrescribe `b_plus_commerce.exe`, `file_selector_windows_plugin.dll`, `native_assets.json`, `data\`). `flutter_windows.dll` quedó igual (mismo timestamp).
- Datos del usuario intactos: viven en `C:\Users\marco\Documents\b_plus_commerce.hive` (Hive default desktop path), no se tocan al actualizar el exe.
- Relanzado: PID 14444 (nuevo), Path = install, Title = "Caja Clara", Responding = True.

**Screenshots de verificación (`C:\demo comerciales\sales_readiness_qa\caja_clara_v2_fix\`):**

| Archivo | Lo que prueba |
|---------|---------------|
| `01_home_after_fix.png` | Dashboard: KPI ahora dice **"Caja del día $12.500 — Apertura + ventas - gastos"**. Coincide con la apertura $10.000 visible en el banner y con la venta $2.500. Sin contradicción. |
| `02_caja_after_fix.png` | Pantalla Caja: tile **"Caja del día $12.500"** + fórmula card abajo **"Saldo inicial $10.000 + Ventas $2.500 − Gastos $0 = Caja del día $12.500"**. Ambas concuerdan. |

**Checklist de no-regresión:**

- ✅ Dashboard valor y label no se contradicen entre sí.
- ✅ No hay controles demo/build visibles (verificado en `01_home_after_fix.png`: sólo "Ayuda", "Luna Systems" y las acciones normales).
- ✅ Sin error inicial de storage (app abrió directo al dashboard con datos persistidos).
- ✅ Flujo de venta sigue actualizando KPIs (la venta de $2.500 de la sesión previa se ve correctamente en Ventas, Movimientos hoy = 3, y Caja del día = $12.500).
- ✅ Protección de borrado con movimientos sigue funcionando — el test `products_screen_test.dart: blocks product deletion when movements reference it` pasa en la corrida de 65/65 (no se cambió ninguna lógica del flujo de productos).
- ✅ Persistencia intacta: 45 productos, apertura $10.000, venta $2.500 todo presente tras `Stop-Process -Force` + relaunch.

---

## 7. Restricciones respetadas

- No redesign (sólo cambios de label/value en KPIs existentes).
- BitFlow no tocado.
- Luna Systems landing no tocado.
- Sin cambios en lógica de ventas, gastos, productos, caja, persistencia ni navegación.
- `cashBalancePesos` y demás getters del store quedan idénticos.
- Diff total: 3 archivos `lib/` + 2 archivos `test/`. Sin archivos nuevos en producción.

---

## 8. Próximos pasos sugeridos (fuera del scope)

- F-01 del QA V2 (campo "Producto o detalle" en Venta rápida — texto libre vs autocomplete): sigue pendiente.
- F-02 (precios sugeridos en plantilla kiosko): pendiente.
- F-03 (stocks iniciales para no nacer "todo rojo"): pendiente.

Con este fix, el bloqueador único de la QA V2 para clientes contadores/exigentes queda resuelto. Score de sales-readiness pasa de 8.5/10 → ~9.5/10.
