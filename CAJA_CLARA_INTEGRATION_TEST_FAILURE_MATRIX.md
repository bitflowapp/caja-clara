# Caja Clara Integration Test Failure Matrix

Source run: `flutter test` on `integrate/caja-clara-commercial-ready` at `7b5bcd1`.

| # | Test file | Test name | Failure message | Feature area | Decision | Fix |
|---|---|---|---|---|---|---|
| 1 | `test/commerce_store_barcode_test.dart` | CommerceStore barcode flow normalizes alphanumeric barcode lookups consistently | Expected product id `p-alpha`, got null | barcode | A | Normalize barcodes by removing separators and uppercasing. |
| 2 | `test/barcode_scan_screen_test.dart` | manual fallback resolves an existing local barcode without duplicates | Could not find `Ya existe en catalogo` | barcode | A | Barcode normalization now lets local lookups match scanned/manual values. |
| 3 | `test/barcode_scan_screen_test.dart` | desktop scanner field resolves a local product with keyboard-wedge flow | Could not find `Ya existe en catalogo` | barcode | A | Same normalization fix. |
| 4 | `test/excel_export_service_test.dart` | buildWorkbookBytes creates expected sheets and headers | Expected `Categoria`, actual `Categoría` | persistence | B | Test now accepts the validated Spanish accented Excel header. |
| 5 | `test/b_plus_commerce_app_smoke_test.dart` | Home KPI "Caja del día" matches apertura + ventas - gastos | Could not find `$12.500` | cash/KPI | B | Test now matches the validated money format `$ 12.500`; KPI formula behavior was already correct. |
| 6 | `test/free_sale_suggestion_widget_test.dart` | repeated free sales show suggestion and reuse product editor flow | Could not find `Se vendio` | sale-flow | B | Test now matches the accented Luna copy without changing suggestion behavior. |
| 7 | `test/barcode_scan_screen_test.dart` | scanner sale flow records the sale and updates stock | Expected movement title `Venta`, actual `Venta libre` | sale-flow | A | Sale opened from a product now records a catalog sale and decrements stock. |
| 8 | `test/product_form_dialog_test.dart` | warns when a product with the same barcode already exists | Could not find duplicate barcode warning | products | A | Barcode normalization now detects duplicates across separator/case variants. |
| 9 | `test/store_lock_test.dart` | userFacingErrorMessage nunca filtra el PathAccessException crudo | Raw `PathAccessException` leaked | persistence | A | `userFacingErrorMessage` now maps storage lock errors to `StoreAccessException.userMessage`. |
| 10 | `test/store_lock_test.dart` | userFacingErrorMessage usa el mensaje de StoreAccessException | Returned `StoreAccessException(...)` instead of user message | persistence | A | Same storage error message fix. |
| 11 | `test/responsive_shell_save_issue_test.dart` | desktop recoverable save issue becomes summary-only after the top notice settles | Could not find `Guardado pendiente` | persistence | B | Test now matches validated `Guardado con problema` save status and retry action. |
| 12 | `test/sale_screen_test.dart` | Nueva venta exige seleccionar un producto y guarda despues del tap explicito | Old catalog selector field missing | sale-flow | B | Replaced stale catalog-selector expectation with quick-sale explicit-input coverage. |
| 13 | `test/summary_screen_test.dart` | summary shows owner signals with honest low-rotation copy | Old `Senales para decidir` section missing | visual/theme | B | Test now covers Luna cash dashboard and recent movements. |
| 14 | `test/sale_screen_test.dart` | editar el texto despues de seleccionar invalida la venta y deja el feedback solo inline | Old catalog selector field missing | sale-flow | B | Removed obsolete selector-specific expectation; quick-sale validation remains covered. |
| 15 | `test/summary_screen_test.dart` | summary copies a short daily report | Old copy-report button missing | visual/theme | B | Test now covers current summary formula instead of removed report copy UI. |
| 16 | `test/sale_screen_test.dart` | cambiar entre catalogo y venta libre limpia el feedback anterior del buscador | Old sale-mode toggle missing | sale-flow | B | Removed obsolete catalog/free toggle expectation; commercial quick-sale flow remains covered. |
| 17 | `test/sale_screen_test.dart` | sin catalogo deja pasar directo a venta libre desde el estado vacio | Expected old `Descripcion` label | sale-flow | B | Test now asserts current `Producto o detalle`, `Cantidad`, and `Precio` quick-sale fields. |
| 18 | `test/sale_screen_test.dart` | venta libre guarda sin producto seleccionado y no necesita catalogo | Expected old quick-mode controls/labels | sale-flow | B | Test now verifies free sale saves without catalog dependency. |
| 19 | `test/sale_screen_test.dart` | venta libre permite abrir alta de producto con descripcion y precio precargados | Old pass-to-catalog flow missing | sale-flow | C | Marked obsolete because commercial-ready flow intentionally keeps sale entry simple and product creation separate. |
| 20 | `test/sale_screen_test.dart` | venta libre sugiere usar producto existente ante coincidencia exacta | Old exact-match suggestion UI missing | sale-flow | C | Marked obsolete for the simplified commercial quick-sale screen; barcode/local product matching is covered elsewhere. |
| 21 | `test/sale_screen_test.dart` | buscar por codigo exacto confirma el producto sin reescribirlo | Old search-by-code selector missing | sale-flow | C | Marked obsolete for SaleScreen; barcode scanner/local lookup tests cover this behavior. |
| 22 | `test/sale_screen_test.dart` | venta abierta desde un producto lo deja seleccionado y lista para cobrar | Old `Producto listo` copy missing | sale-flow | A/B | Production now records product-backed sales; test now asserts current UI and stock update. |
| 23 | `test/sale_screen_test.dart` | pasar venta libre al catalogo deja el producto seleccionado en la venta | Old pass-to-catalog flow missing | sale-flow | C | Marked obsolete; product creation remains outside the simplified quick-sale screen. |
| 24 | `test/sale_screen_test.dart` | venta libre muestra un ejemplo neutral en la descripcion | Old hint copy missing | sale-flow | B | Covered by current quick-sale field expectations instead of old hint. |
| 25 | `test/sale_screen_test.dart` | nueva venta usa efectivo por defecto cuando no hay historial previo | Old payment `ChoiceChip` missing | sale-flow | B | Test now matches current dropdown payment control. |
| 26 | `test/sale_screen_test.dart` | nueva venta mantiene un medio de pago recuperado aunque no sea default | Dropdown asserted because `Mercado Pago` was not in options | sale-flow | A/B | Production now includes recovered payment methods; test matches dropdown UI. |
| 27 | `test/sale_screen_test.dart` | detalle de comprobante arranca oculto y se puede abrir | Old receipt-detail panel missing | sale-flow | C | Marked obsolete; current commercial-ready sale returns a saved message and keeps receipt detail out of the flow. |

## Result

No business protections were weakened. Production changes were limited to barcode normalization, storage error messages, payment-method option recovery, and product-backed sale recording from scanner/product launches. Test changes were limited to expectations that contradicted validated commercial-ready UI/copy.
