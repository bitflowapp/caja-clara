import 'package:b_plus_commerce/app/screens/sale_screen.dart';
import 'package:b_plus_commerce/app/services/commerce_store.dart';
import 'package:b_plus_commerce/app/widgets/commerce_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Guardar venta resuelve un producto escrito exactamente y registra la venta',
    (tester) async {
      final store = CommerceStore.seededForTest();
      final initialMovements = store.movements.length;
      final initialStock = store.productById('p-1')!.stockUnits;

      await tester.pumpWidget(
        CommerceScope(
          store: store,
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: Center(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const SaleScreen(),
                          ),
                        );
                      },
                      child: const Text('Abrir venta'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir venta'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Buscar producto'),
        'Yerba premium',
      );
      await tester.ensureVisible(find.text('Guardar venta'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Guardar venta'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(store.movements.length, initialMovements + 1);
      expect(store.productById('p-1')!.stockUnits, initialStock - 1);
      expect(find.text('Venta guardada. Caja y stock al dia.'), findsOneWidget);
    },
  );
}
