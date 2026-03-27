import 'package:b_plus_commerce/app/screens/products_screen.dart';
import 'package:b_plus_commerce/app/services/commerce_store.dart';
import 'package:b_plus_commerce/app/widgets/commerce_scope.dart';
import 'package:b_plus_commerce/app/models/product.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpProductsScreen(
    WidgetTester tester,
    CommerceStore store, {
    Future<void> Function(Product product)? onSellProduct,
  }) async {
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
              onSellProduct: onSellProduct,
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

  testWidgets('products screen surfaces desktop badges and quick sell action', (
    tester,
  ) async {
    final store = CommerceStore.emptyForTest();
    await store.addProduct(
      const Product(
        id: 'cafe',
        name: 'Cafe molido',
        stockUnits: 8,
        minStockUnits: 2,
        costPesos: 3200,
        pricePesos: 5400,
        category: 'Almacen',
      ),
    );
    await store.addProduct(
      const Product(
        id: 'lapiz',
        name: 'Lapiz negro',
        stockUnits: 1,
        minStockUnits: 3,
        costPesos: 120,
        pricePesos: 0,
        category: 'Libreria',
      ),
    );

      await pumpProductsScreen(
      tester,
      store,
      onSellProduct: (_) async {},
    );

    expect(find.text('Sin codigo'), findsAtLeastNWidgets(2));
    expect(find.text('Sin precio'), findsOneWidget);
    expect(find.text('Vender'), findsAtLeastNWidgets(1));
  });
}
