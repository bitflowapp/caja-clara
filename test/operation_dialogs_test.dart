import 'package:b_plus_commerce/app/widgets/operation_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('amount dialog accepts zero when allowZero is enabled', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final result = ValueNotifier<int?>(null);
    addTearDown(result.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () async {
                    result.value = await showAmountEntryDialog(
                      context,
                      title: 'Apertura de caja',
                      label: 'Caja inicial',
                      confirmLabel: 'Guardar',
                      initialValue: 0,
                      allowZero: true,
                    );
                  },
                  child: const Text('Abrir monto'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Abrir monto'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, 'Caja inicial'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Caja inicial'),
      '0',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(result.value, 0);
    expect(find.text('Ingresa un valor igual o mayor a 0.'), findsNothing);
  });
}
