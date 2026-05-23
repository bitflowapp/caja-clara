import 'package:b_plus_commerce/app/screens/products_screen.dart';
import 'package:b_plus_commerce/app/services/commerce_store.dart';
import 'package:b_plus_commerce/app/widgets/commerce_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('blocks product deletion when movements reference it', (
    tester,
  ) async {
    final store = CommerceStore.emptyForTest();
    await store.loadCommercialDemo();

    await tester.pumpWidget(
      CommerceScope(
        store: store,
        child: MaterialApp(
          home: Scaffold(
            body: ProductsScreen(
              onApplyStarterTemplate: () async {},
              applyingStarterTemplate: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Gaseosa');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('Gaseosa cola 2.25 L'), findsOneWidget);
    await tester.tap(find.byTooltip('Acciones'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar').last);
    await tester.pumpAndSettle();

    expect(find.text('No se puede eliminar'), findsOneWidget);
    expect(find.textContaining('proteger el historial'), findsOneWidget);
    expect(store.productById('demo-product-gaseosa-cola'), isNotNull);
  });
}
