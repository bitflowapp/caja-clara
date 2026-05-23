# Caja Clara Sales-Readiness Fix Report

Date: 2026-05-23
Scope: Caja Clara only. No BitFlow, Luna Systems landing, push, or deploy work was performed.

## Summary

Fixed the sales-readiness blockers found in the installed Windows QA pass:

- Normal builds no longer expose commercial demo controls or build metadata.
- First-use empty storage no longer attempts an unnecessary initial save that can surface a storage warning.
- Starter template product IDs are now unique even when many products are created in the same microsecond.
- Older local snapshots with duplicate product IDs are repaired on load instead of causing the installed app to show the storage error and drop to an empty state.
- Product deletion with related movements is blocked before any destructive confirmation, with clear history-protection feedback.

## Files Changed

- `lib/app/screens/home_screen.dart`
- `lib/app/screens/products_screen.dart`
- `lib/app/services/commerce_store.dart`
- `lib/app/widgets/input_shortcuts.dart`
- `lib/app/widgets/responsive_shell.dart`
- `test/b_plus_commerce_app_smoke_test.dart`
- `test/commerce_store_template_test.dart`
- `test/products_screen_test.dart`
- `test/store_lock_test.dart`
- `CAJA_CLARA_SALES_READINESS_FIX_REPORT.md`

## Validation

Passed:

- `flutter clean`
- `flutter pub get`
- `flutter analyze`
- `flutter test`
- `flutter build windows`
- `flutter build web`

Note: `flutter build web` completed successfully and reported the existing Flutter Wasm dry-run warning from `speech_to_text` using `dart:html` / JS interop. This did not fail the requested build.

## Installed Windows QA

Installed app updated from:

- `build\windows\x64\runner\Release`

Installed executable verified:

- `C:\Users\marco\AppData\Local\CajaClara\b_plus_commerce.exe`

Manual checks passed:

- Process path points to the installed EXE.
- Normal launch hides `Demo comercial`, `Probá con datos de demo`, `Limpiar datos de demo`, `Restablecer demo`, and build metadata.
- Existing local data that previously triggered the storage banner now loads without `No se pudo abrir el almacenamiento`.
- Sidebar save chip shows `Todo guardado`.
- Kiosk template loads products.
- Product without related movements can be deleted through the normal destructive confirmation.
- Product with a stock movement cannot be deleted; app shows `No se puede eliminar` and explains that history is protected.
- Close/reopen preserves local state and does not show the storage banner.

## Screenshots

Saved under:

- `C:\demo comerciales\sales_readiness_qa\caja_clara_fix\caja_clara_fix_home.png`
- `C:\demo comerciales\sales_readiness_qa\caja_clara_fix\caja_clara_fix_delete_no_history_dialog.png`
- `C:\demo comerciales\sales_readiness_qa\caja_clara_fix\caja_clara_fix_product_deleted.png`
- `C:\demo comerciales\sales_readiness_qa\caja_clara_fix\caja_clara_fix_stock_adjusted.png`
- `C:\demo comerciales\sales_readiness_qa\caja_clara_fix\caja_clara_fix_related_delete_blocked.png`
- `C:\demo comerciales\sales_readiness_qa\caja_clara_fix\caja_clara_fix_reopened_after_repair_taskbar.png`
- `C:\demo comerciales\sales_readiness_qa\caja_clara_fix\caja_clara_fix_related_delete_blocked_after_repair.png`

## Commercial Readiness

Caja Clara is now ready for early guided demos and pilot conversations from the tested blocker perspective.

Residual notes:

- The app still uses the current three-section navigation (`Inicio`, `Productos`, `Caja`); dedicated top-level `Ventas` and `Gastos` sections remain a future UX improvement.
- Web builds pass, but Wasm readiness would require replacing or isolating the current `speech_to_text` web implementation.
