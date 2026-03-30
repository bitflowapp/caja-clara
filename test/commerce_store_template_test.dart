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
      expect(
        store.initialCatalogSetupStatus,
        InitialCatalogSetupStatus.pending,
      );
      expect(store.shouldPromptInitialCatalogSetup, isTrue);
    });

    test('loads commercial demo data from the empty first-use state', () async {
      final store = CommerceStore.emptyForTest();

      await store.loadDemoData();

      expect(store.hasProducts, isTrue);
      expect(store.hasMovements, isTrue);
      expect(store.products.length, 5);
      expect(store.productsWithBarcodeCount, 5);
      expect(store.sellableProductsCount, greaterThan(0));
      expect(store.estimatedInventoryCostPesos, greaterThan(0));
      expect(store.movements.first.title, 'Venta');
      expect(
        store.initialCatalogSetupStatus,
        InitialCatalogSetupStatus.example,
      );
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

    test('uses neutral products in the starter template', () async {
      final store = CommerceStore.emptyForTest();

      await store.applyArgentinianKioskTemplate();

      expect(
        store.products.where(
          (product) => product.name.toLowerCase().contains('preserv'),
        ),
        isEmpty,
      );
      expect(
        store.products.where((product) => product.name == 'Pasta dental chica'),
        hasLength(1),
      );
      expect(
        store.products.where((product) => product.name == 'Jabon de tocador'),
        hasLength(1),
      );
    });

    test('blocks loading demo data when the app already has data', () async {
      final store = CommerceStore.emptyForTest();

      await store.applyArgentinianKioskTemplate();

      await expectLater(store.loadDemoData(), throwsA(isA<StateError>()));
    });

    test('marks empty start without loading products', () async {
      final store = CommerceStore.emptyForTest();

      await store.chooseEmptyCatalogStart();

      expect(store.products, isEmpty);
      expect(store.movements, isEmpty);
      expect(store.initialCatalogSetupStatus, InitialCatalogSetupStatus.empty);
      expect(store.shouldPromptInitialCatalogSetup, isFalse);
    });

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
