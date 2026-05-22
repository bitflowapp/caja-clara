# Caja Clara delete and demo cleanup report

Date: 2026-05-22

## Current issue found

Product deletion existed, but it was easy to miss because it lived in the product row overflow menu. Demo data could be loaded or replaced with another demo, but there was no clear way to clean the app back to an empty state after testing.

## Files changed

- `CAJA_CLARA_DELETE_AND_DEMO_CLEANUP_AUDIT.md`
- `CAJA_CLARA_DELETE_AND_DEMO_CLEANUP_REPORT.md`
- `lib/app/services/commerce_store.dart`
- `lib/app/screens/products_screen.dart`
- `lib/app/screens/home_screen.dart`
- `lib/app/widgets/responsive_shell.dart`
- `test/commerce_store_template_test.dart`

## Product deletion behavior implemented

- Added a visible `Eliminar` button with a trash icon on each product card.
- Updated the confirmation dialog to use:
  - Title: `¿Eliminar producto?`
  - Body starts with: `Esta acción no se puede deshacer.`
- Kept snackbar feedback after successful deletion.
- Kept the existing error snackbar path when deletion is blocked.

## Demo cleanup behavior implemented

- Added `Limpiar datos de demo` in the home demo area when identifiable commercial demo data exists.
- Added confirmation:
  - Title: `Limpiar datos de demo`
  - Body: `Se eliminarán los datos de ejemplo cargados para probar Caja Clara. Tus datos reales no deberían verse afectados.`
- Added `Restablecer Caja Clara` as a full reset option.
- Full reset requires typing `RESTABLECER`.
- Full reset confirmation uses:
  - Title: `Restablecer Caja Clara`
  - Body: `Esto eliminará productos, ventas, gastos y movimientos guardados en este dispositivo.`
- After cleanup or full reset, the home empty state says `Caja Clara está lista para empezar.` and offers product/demo actions.

## Dependency safety behavior

- Product deletion remains a hard delete only when the product has no related movements.
- If a product has sales or stock adjustments, deletion is blocked to preserve history, exports, undo logic, stock integrity, and cash reporting.
- Demo cleanup removes identifiable demo products and demo movements. It also removes movements that reference demo product ids, so no orphaned product references remain.
- Full reset clears products, movements, dismissed suggestions, and cash opening/closing state on this device.

## Validation results

- `flutter clean`: passed after stopping a stale running `b_plus_commerce.exe` that initially held the build output lock.
- `flutter pub get`: passed.
- `flutter analyze`: passed, no issues found.
- `flutter test`: passed, 57 tests.
- `flutter build windows`: passed after releasing the stale executable lock.
- `flutter build web`: passed. Flutter reported existing Wasm dry-run warnings from `speech_to_text` web dependencies using `dart:html` / JS interop.

## Manual checks

- Loaded demo data and verified the cleanup action renders.
- Opened Products and verified the visible delete action renders.
- Opened the delete confirmation dialog.
- Verified linked product deletion is blocked by store tests.
- Cleaned demo data and verified the empty state renders.
- Verified dashboard/products state updates through store notifications and widget rendering.
- Verified no analyzer, test, Windows build, or web build failures after the changes.

## Screenshots

Saved in `C:\demo comerciales\visual_redesign_review\`:

- `caja_clara_delete_product_dialog.png`
- `caja_clara_demo_cleanup_action.png`
- `caja_clara_empty_after_cleanup.png`

## Known risks

- Demo cleanup identifies commercial demo records by the current `demo-product-*` and `demo-*` id prefixes. Older seed/test data with ids like `p-1` or `m-1` is not treated as safely identifiable commercial demo data.
- If a user records additional trial movements against demo products, cleanup removes those movements too because they depend on demo product ids. This avoids broken history references but assumes those movements are part of demo testing.
- Full reset is intentionally broad and device-local; it should only be used after the typed confirmation.
