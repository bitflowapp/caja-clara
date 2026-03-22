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
  });
}
