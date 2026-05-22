# Caja Clara delete and demo cleanup audit

Date: 2026-05-22

## Current issue found

Marco's concern is valid: demo data was easy to load or reset, but cleanup was framed as "Reiniciar demo", which replaces the current state with another demo instead of making the app clean again. Product deletion existed, but it was only inside the row overflow menu, so it was easy to miss while trying to remove loaded examples.

## Where demo data is created or loaded

- `lib/app/services/commerce_store.dart`
  - `loadCommercialDemo()` loads commercial demo data only when the app is empty.
  - `resetCommercialDemo()` replaces the current store contents with the commercial demo.
  - `_applyCommercialDemo()` creates identifiable demo records using `demo-product-*` product ids and `demo-*` movement ids.
- `lib/app/screens/home_screen.dart`
  - `_StarterTemplateCard` exposes "Probá con datos de demo" when the app is empty.
  - `_CommercialDemoCard` exposed "Reiniciar demo" when products or movements exist.
- `lib/app/widgets/responsive_shell.dart`
  - `_loadCommercialDemo()` and `_resetCommercialDemo()` connect the home actions to the store.

## Where products are stored

- Products are held in memory in `CommerceStore._products`.
- They are persisted through `CommercePersistence` in the normal store snapshot.
- The persisted snapshot also includes movements, dismissed suggestions, and cash opening/closing state.

## Current product deletion behavior

- `CommerceStore.removeProduct(productId)` already existed.
- It hard-deletes a product only when no movement references `movement.productId == productId`.
- If any sale or stock adjustment references the product, deletion is blocked with a `StateError`.

## UX gap

- Product deletion was present but hidden in the product tile popup menu.
- The visible product actions were "Editar" and "Ajustar stock"; there was no visible delete affordance.
- The confirmation explained that linked movement deletion would be blocked, but the title/copy was not the requested direct warning.

## Dependency safety

The safest current behavior is to keep hard deletion only for products with no related movements. Products with sales or stock movements must stay in the catalog so historical sales, stock adjustments, undo logic, exports, and cash reports remain consistent.

Chosen behavior:

- Delete product if it has no movement dependencies.
- Block deletion if it has sales or stock adjustments.
- Show a clear error through the existing snackbar path.
- Do not change movement history or business rules.

## Demo cleanup/reset gap

- Identifiable commercial demo data exists because ids are prefixed.
- There was no "Limpiar datos de demo" action.
- There was no full clean reset action guarded by typing confirmation.

Chosen behavior:

- Add "Limpiar datos de demo" when identifiable commercial demo data exists.
- Remove demo products and demo movements, including movements that reference demo product ids.
- Add "Restablecer Caja Clara" as the fallback full reset, guarded by typing `RESTABLECER`.
- Keep the existing "Restablecer demo" path for replacing non-demo current data with the commercial demo.

## Empty state target

After cleanup or reset, the home empty state should clearly say:

- "Caja Clara está lista para empezar."
- CTA: "Cargar producto"
- CTA: "Registrar venta" through the existing primary sale action.
- Optional CTA: "Cargar datos de demo"
