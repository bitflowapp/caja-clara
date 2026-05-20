import 'package:b_plus_commerce/app/services/commerce_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CommerceStore starter template', () {
    test('starts empty in the real first-use state for tests', () {
      final store = CommerceStore.emptyForTest();

      expect(store.products, isEmpty);
      expect(store.movements, isEmpty);
      expect(store.hasProducts, isFalse);
      expect(store.hasMovements, isFalse);
    });

    test(
      'applies argentinian kiosk template once without duplicates',
      () async {
        final store = CommerceStore.emptyForTest();

        final firstResult = await store.applyArgentinianKioskTemplate();
        final secondResult = await store.applyArgentinianKioskTemplate();

        expect(firstResult.addedCount, greaterThan(40));
        expect(firstResult.skippedCount, 0);
        expect(store.products.length, firstResult.totalCount);
        expect(
          store.products.where((product) => product.name == 'Coca-Cola 500 ml'),
          hasLength(1),
        );
        expect(secondResult.addedCount, 0);
        expect(secondResult.fullySkipped, isTrue);
        expect(store.products.length, firstResult.totalCount);
      },
    );

    test('allows zero price but blocks sale until price is defined', () async {
      final store = CommerceStore.emptyForTest();

      await store.applyArgentinianKioskTemplate();
      final product = store.products.firstWhere(
        (item) => item.name == 'Agua 500 ml',
      );

      await store.addStockToProduct(
        productId: product.id,
        quantityUnits: 3,
        note: 'Alta inicial',
      );

      await expectLater(
        store.recordSale(
          productId: product.id,
          quantityUnits: 1,
          paymentMethod: 'Efectivo',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('commercial demo uses neutral data and can be reset', () async {
      final store = CommerceStore.emptyForTest();

      final firstResult = await store.loadCommercialDemo();
      await store.recordFreeSale(
        description: 'Venta de grabación',
        quantityUnits: 1,
        unitPricePesos: 2500,
        paymentMethod: 'Efectivo',
      );
      await store.recordExpense(
        concept: 'Gasto de grabación',
        amountPesos: 900,
        category: 'Insumos',
      );
      final resetResult = await store.resetCommercialDemo();

      expect(firstResult.applied, isTrue);
      expect(firstResult.productCount, 10);
      expect(firstResult.movementCount, 8);
      expect(resetResult.applied, isTrue);
      expect(store.products, hasLength(resetResult.productCount));
      expect(store.movements, hasLength(resetResult.movementCount));
      expect(
        store.products.map((product) => product.name.toLowerCase()),
        everyElement(isNot(contains('coca'))),
      );
      expect(
        store.products.map((product) => product.id),
        contains('demo-product-gaseosa-cola'),
      );
      expect(store.hasMovements, isTrue);
      expect(store.todaySalesPesos, greaterThan(0));
      expect(store.todayExpensesPesos, greaterThan(0));
    });
  });
}
