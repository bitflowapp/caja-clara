# Caja Clara Integration Test Fix Report

## Root Cause Summary

The integration branch combined validated commercial-ready behavior with newer `origin/main` test expectations. The failures came from two sources:

- Real integration gaps: barcode normalization did not match scanner/manual lookup expectations; storage errors could leak technical exception text; the sale screen did not include recovered non-default payment methods; product-backed scanner sales were being saved as free sales.
- Outdated tests: several tests still expected the pre-Luna catalog sale selector, receipt-detail UI, unaccented Spanish copy, old save-status wording, and old summary "signals" report. Those expectations contradicted the validated commercial-ready UI and were updated instead of changing the product back.

## Failing Tests Fixed

See `CAJA_CLARA_INTEGRATION_TEST_FAILURE_MATRIX.md` for the full 27-test matrix with feature area, failure message, and A/B/C decision.

Production-code fixes:

- `test/commerce_store_barcode_test.dart`: barcode normalization.
- `test/barcode_scan_screen_test.dart`: local barcode lookup and scanner sale stock update.
- `test/product_form_dialog_test.dart`: duplicate barcode detection after normalization.
- `test/store_lock_test.dart`: human-safe storage error messages.
- `test/sale_screen_test.dart`: product-backed sale from scanner/product launch and recovered payment method.

Test-expectation fixes:

- `test/b_plus_commerce_app_smoke_test.dart`: validated money format for Caja del día KPI.
- `test/excel_export_service_test.dart`: validated accented Excel header.
- `test/free_sale_suggestion_widget_test.dart`: validated accented Luna copy.
- `test/responsive_shell_save_issue_test.dart`: validated save-status copy.
- `test/sale_screen_test.dart`: current commercial quick-sale UI instead of obsolete catalog selector/receipt expectations.
- `test/summary_screen_test.dart`: current Luna cash dashboard/formula instead of obsolete decision-signals report.

Obsolete/superseded expectations:

- SaleScreen pass-to-catalog flows and exact-code catalog selector flows were not restored because the commercial-ready SaleScreen intentionally uses the simplified quick-sale flow.
- Barcode/local product lookup remains covered in barcode scanner tests.
- Product creation remains covered by product dialog/suggestion flows, not by reintroducing the old sale-screen catalog editor path.

## Files Changed

- `lib/app/services/commerce_store.dart`: normalize barcodes by removing non-alphanumeric separators and uppercasing.
- `lib/app/utils/user_facing_errors.dart`: map `StoreAccessException` and raw storage lock/permission errors to safe user-facing messages.
- `lib/app/screens/sale_screen.dart`: recover supported/non-default payment methods, record product-backed sales when launched with an initial product, and surface product sale readiness warnings.
- `test/sale_screen_test.dart`: replaced stale catalog-selector tests with commercial quick-sale and product-backed sale coverage.
- `test/summary_screen_test.dart`: updated to current Luna summary dashboard/formula.
- `test/b_plus_commerce_app_smoke_test.dart`: money format expectation.
- `test/excel_export_service_test.dart`: accented header expectation.
- `test/free_sale_suggestion_widget_test.dart`: accented copy expectation.
- `test/responsive_shell_save_issue_test.dart`: save-status expectation.
- `CAJA_CLARA_INTEGRATION_TEST_FAILURE_MATRIX.md`: original 27-failure matrix.
- `CAJA_CLARA_INTEGRATION_TEST_FIX_REPORT.md`: this report.

## Commercial-Ready Behavior Preserved

- Normal app launch has no demo/build controls: existing smoke test still passes.
- No initial storage error: no startup storage error was introduced; validation passed.
- Product with related movements cannot be destructively deleted: product deletion safety tests pass.
- Product without related movements can be deleted: existing product deletion behavior unchanged.
- Caja del día shows opening + sales - expenses: store hardening and app smoke tests pass.
- Demo controls remain gated behind `CAJA_CLARA_DEMO_CONTROLS`: existing launch/smoke behavior unchanged.
- Excel export remains valid: Excel export tests pass with validated Spanish header.
- Luna UI remains intact: summary/home tests now target current Luna dashboard and copy.
- Scanner/product sale behavior preserved and improved: sales launched from a product now record catalog sales and decrement stock.

## Validation Results

- `flutter clean`: passed.
- `flutter pub get`: passed.
- `flutter analyze`: passed, no issues found.
- `flutter test`: passed, 86 tests passed.
- `flutter build windows`: passed, built `build\windows\x64\runner\Release\CajaClara.exe`.
- `flutter build web`: passed, built `build\web`.

Note: `flutter build web` emitted Flutter's WebAssembly dry-run warnings for `speech_to_text` web dependencies (`dart:html` / `dart:js_util`), but the standard web build completed successfully.

## PR Status

- Branch: `integrate/caja-clara-commercial-ready`.
- PR: `https://github.com/bitflowapp/caja-clara/pull/1`.
- PR was not merged.
- No force push was used.
- `origin/main` was not rewritten.
