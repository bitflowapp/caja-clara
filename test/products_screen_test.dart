import 'package:b_plus_commerce/app/screens/products_screen.dart';
import 'package:b_plus_commerce/app/services/commerce_store.dart';
import 'package:b_plus_commerce/app/widgets/commerce_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpProductsScreen(
    WidgetTester tester,
    CommerceStore store,
  ) async {
    await tester.pumpWidget(
      CommerceScope(
        store: store,
        child: MaterialApp(
          home: Scaffold(
            body: ProductsScreen(
              onApplyStarterTemplate: () async {},
              applyingStarterTemplate: false,
              onLoadDemoData: () async {},
              loadingDemoData: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'products screen hides demo CTA when there are movements without catalog',
    (tester) async {
      final store = CommerceStore.emptyForTest();
      await store.recordFreeSale(
        description: 'Venta mostrador',
        quantityUnits: 1,
        unitPricePesos: 2500,
        paymentMethod: 'Efectivo',
      );

      await pumpProductsScreen(tester, store);

      expect(find.text('Demo comercial'), findsNothing);
      expect(find.text('Cargar demo comercial'), findsNothing);
      expect(find.text('Plantilla kiosco'), findsOneWidget);
    },
  );
}
