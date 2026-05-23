# Caja Clara Demo Source Review

Date: 2026-05-23
Repository: `D:\bit flow hoy actualizado 12.2\caja-clara`

Scope: review the remaining modified Dart files only. No source files were changed, staged, committed, or pushed during this review.

## Files Reviewed

- `lib/app/screens/expense_screen.dart`
- `lib/app/screens/sale_screen.dart`
- `lib/app/widgets/input_shortcuts.dart`
- `lib/app/widgets/speech_dictation.dart`

## Diff Summary

```text
lib/app/screens/expense_screen.dart   | 57 +++++++++++++++++++++++++----------
lib/app/screens/sale_screen.dart      | 16 ++++++++++
lib/app/widgets/input_shortcuts.dart  | 21 +++++++++++++
lib/app/widgets/speech_dictation.dart | 10 ++++++
4 files changed, 88 insertions(+), 16 deletions(-)
```

## Gating Assessment

The demo behavior is controlled by:

```dart
static const demoAutofillEnabled = bool.fromEnvironment(
  'CAJA_CLARA_DEMO_CONTROLS',
);
```

This is a compile-time environment flag. If the app is built normally, `bool.fromEnvironment` defaults to `false`. The search found no build script, app entrypoint, test, or source file that enables `CAJA_CLARA_DEMO_CONTROLS` automatically.

Conclusion: normal users should not see the demo autofill shortcut, seeded demo field values, or hidden dictation UI unless a build is explicitly compiled with `--dart-define=CAJA_CLARA_DEMO_CONTROLS=true`.

## File-by-File Review

### `lib/app/widgets/input_shortcuts.dart`

What changed:

- Adds `DemoAutofillShortcutIntent`.
- Adds compile-time flag `InputShortcutScope.demoAutofillEnabled`.
- Adds optional `onDemoAutofill` callback.
- Registers `Alt+D` only when both conditions are true:
  - `demoAutofillEnabled == true`
  - `onDemoAutofill != null`
- Adds a matching action that calls `onDemoAutofill`.

Classification: demo-only but acceptable behind `CAJA_CLARA_DEMO_CONTROLS`.

Risk:

- Low for normal production builds because the shortcut map/action are not registered unless the compile-time flag is true.
- Medium if a production/release build accidentally sets the flag, because `Alt+D` becomes an undocumented data-entry shortcut.

Recommendation: keep only if Caja Clara wants a maintained reproducible demo mode. Revert if the demo recording work is finished and should not remain in production source.

### `lib/app/screens/sale_screen.dart`

What changed:

- When there is no initial sale draft and demo controls are enabled, pre-fills:
  - description: `Café frío`
  - quantity: `2`
  - unit price: `1800`
- Wires `onDemoAutofill` into `InputShortcutScope`.
- Adds `_fillPremiumDemoSale`, which fills the same values, sets payment method to `Efectivo`, disables autovalidation, and dismisses the keyboard.

Classification: demo-only but acceptable behind `CAJA_CLARA_DEMO_CONTROLS`.

Risk:

- Low for normal production builds because values are not prefilled unless the flag is true.
- Medium if the flag is accidentally enabled in a real customer build, because the sale form opens with fake sale data.
- The demo strings are business-specific sample data, not a general production improvement.

Recommendation: keep only as part of a deliberate demo-controls feature. Otherwise revert.

### `lib/app/screens/expense_screen.dart`

What changed:

- When demo controls are enabled, pre-fills:
  - concept: `Bolsas`
  - amount: `900`
  - category: `Insumos`
- Skips speech dictation initialization when demo controls are enabled.
- Hides speech dictation UI in this screen when demo controls are enabled.
- Wires `onDemoAutofill` into `InputShortcutScope`.
- Adds `_fillPremiumDemoExpense`, which fills the same demo values and dismisses the keyboard.

Classification: demo-only but acceptable behind `CAJA_CLARA_DEMO_CONTROLS`, with one caution.

Risk:

- Low for normal production builds because the flag defaults to false.
- Medium if the flag is accidentally enabled, because the expense form opens with fake data and dictation is disabled.
- Caution: this file has both local hiding of dictation UI and the shared hiding added in `speech_dictation.dart`; the local screen-level condition is somewhat redundant.

Recommendation: keep only as part of a deliberate demo-controls feature. Otherwise revert.

### `lib/app/widgets/speech_dictation.dart`

What changed:

- Imports `input_shortcuts.dart`.
- Makes `SpeechDictationActionButton` return `SizedBox.shrink()` when demo controls are enabled.
- Makes `SpeechDictationHint` return `SizedBox.shrink()` when demo controls are enabled.

Classification: demo-only but acceptable behind `CAJA_CLARA_DEMO_CONTROLS`, but more invasive than the screen-specific changes.

Risk:

- Low for normal production builds because the flag defaults to false.
- Medium if the flag is enabled, because this suppresses speech dictation UI globally anywhere these widgets are used.
- Architectural caution: a generic speech widget now imports shortcut/demo infrastructure. This couples a reusable UI component to a demo-control feature.

Recommendation: if keeping demo mode, consider whether dictation should be hidden at the screen level only, or documented as an intentional global demo-mode behavior. If not keeping demo mode, revert.

## Overall Recommendation

The changes are clearly gated and should not affect normal users accidentally unless a build explicitly sets:

```text
--dart-define=CAJA_CLARA_DEMO_CONTROLS=true
```

However, these are not safe production improvements. They are demo/video-recording support embedded in production source. The right decision depends on product intent:

- Keep and commit if Caja Clara wants a maintained demo mode for repeatable screenshots/videos/sales demos.
- Revert if the demo/video recording work is complete and the goal is to keep production source free of temporary demo behavior.

My recommendation: keep only if you document `CAJA_CLARA_DEMO_CONTROLS` as an intentional internal demo feature. Otherwise revert all four files together.

## Commit Recommendation If Kept

Commit all four files together. Do not split them, because the screen changes depend on `InputShortcutScope.demoAutofillEnabled` and `onDemoAutofill`.

Recommended commit message:

```text
Add gated Caja Clara demo controls
```

Before committing, run:

```powershell
git diff --check
flutter analyze
flutter test
```

Optional manual verification:

```powershell
flutter run -d windows --dart-define=CAJA_CLARA_DEMO_CONTROLS=true
```

Then verify:

- sale form pre-fills demo sale values
- expense form pre-fills demo expense values
- `Alt+D` refills values
- dictation UI is hidden in demo mode
- normal build without the flag has no prefilled demo values and dictation remains visible

## Rollback Instructions If Reverted

To revert only these four Dart files and leave reports/other dirty files alone:

```powershell
git restore -- lib/app/screens/expense_screen.dart lib/app/screens/sale_screen.dart lib/app/widgets/input_shortcuts.dart lib/app/widgets/speech_dictation.dart
```

Then verify:

```powershell
git status --short
flutter analyze
flutter test
```

Do not use `git reset --hard`, because there are unrelated untracked report files in the working tree.
