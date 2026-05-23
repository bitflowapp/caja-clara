import 'package:b_plus_commerce/app/services/commerce_store.dart';
import 'package:b_plus_commerce/app/services/commerce_persistence.dart';
import 'package:b_plus_commerce/app/models/product.dart';
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
          store.products.map((product) => product.id).toSet(),
          hasLength(store.products.length),
        );
        expect(
          store.products.where((product) => product.name == 'Coca-Cola 500 ml'),
          hasLength(1),
        );
        expect(secondResult.addedCount, 0);
        expect(secondResult.fullySkipped, isTrue);
        expect(store.products.length, firstResult.totalCount);
      },
    );

    test('starter template snapshot reloads with stable product ids', () async {
      final source = CommerceStore.emptyForTest();

      await source.applyArgentinianKioskTemplate();
      final product = source.products.first;
      await source.addStockToProduct(
        productId: product.id,
        quantityUnits: 2,
        note: 'Alta inicial',
      );

      final restored = await CommerceStore.loadWithPersistenceForTest(
        _SnapshotPersistence(source.buildSnapshot()),
      );

      expect(restored.lastError, isNull);
      expect(restored.products, hasLength(source.products.length));
      expect(restored.movements, hasLength(source.movements.length));
      expect(
        restored.products.map((product) => product.id).toSet(),
        hasLength(restored.products.length),
      );
      expect(restored.productHasMovements(product.id), isTrue);
    });

    test('repairs duplicate product ids from older local snapshots', () async {
      final duplicateSnapshot = <String, dynamic>{
        'version': 2,
        'products': [
          {
            'id': 'product-duplicate',
            'name': 'Aceite',
            'stockUnits': 2,
            'minStockUnits': 1,
            'costPesos': 0,
            'pricePesos': 0,
            'category': 'Almacen',
          },
          {
            'id': 'product-duplicate',
            'name': 'Agua',
            'stockUnits': 0,
            'minStockUnits': 1,
            'costPesos': 0,
            'pricePesos': 0,
            'category': 'Bebidas',
          },
        ],
        'movements': [
          {
            'id': 'stock-1',
            'kind': 'adjustment',
            'origin': 'adjustment',
            'amountPesos': 0,
            'createdAt': DateTime.now().toIso8601String(),
            'title': 'Ingreso de stock',
            'subtitle': 'Aceite / +2 u.',
            'productId': 'product-duplicate',
            'quantityUnits': 2,
            'cashImpactOverridePesos': 0,
            'estimatedProfitImpactOverridePesos': 0,
          },
        ],
        'dismissedFreeSaleSuggestions': <String>[],
      };

      final restored = await CommerceStore.loadWithPersistenceForTest(
        _SnapshotPersistence(duplicateSnapshot),
      );

      expect(restored.lastError, isNull);
      expect(restored.products, hasLength(2));
      expect(
        restored.products.map((product) => product.id).toSet(),
        hasLength(2),
      );
      expect(restored.productHasMovements('product-duplicate'), isTrue);
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

    test(
      'cleans identifiable commercial demo data without full reset',
      () async {
        final store = CommerceStore.emptyForTest();

        await store.loadCommercialDemo();
        await store.addProduct(
          const Product(
            id: 'real-product-1',
            name: 'Producto real',
            stockUnits: 4,
            minStockUnits: 1,
            costPesos: 100,
            pricePesos: 200,
          ),
        );

        final result = await store.cleanCommercialDemoData();

        expect(result.applied, isTrue);
        expect(result.productCount, 10);
        expect(result.movementCount, 8);
        expect(store.hasCommercialDemoData, isFalse);
        expect(store.products.map((product) => product.id), ['real-product-1']);
        expect(store.movements, isEmpty);
      },
    );

    test('reset all data returns the store to a clean state', () async {
      final store = CommerceStore.emptyForTest();

      await store.loadCommercialDemo();
      await store.resetAllData();

      expect(store.products, isEmpty);
      expect(store.movements, isEmpty);
      expect(store.hasProducts, isFalse);
      expect(store.hasMovements, isFalse);
      expect(store.hasCommercialDemoData, isFalse);
    });

    test(
      'product deletion is blocked when history references the product',
      () async {
        final store = CommerceStore.emptyForTest();

        await store.loadCommercialDemo();
        final product = store.products.firstWhere(
          (item) => item.id == 'demo-product-gaseosa-cola',
        );

        expect(store.productHasMovements(product.id), isTrue);
        await expectLater(
          store.removeProduct(product.id),
          throwsA(isA<StateError>()),
        );
        expect(store.productById(product.id), isNotNull);
      },
    );
  });
}

class _SnapshotPersistence extends CommercePersistence {
  _SnapshotPersistence(this.snapshot);

  final Map<String, dynamic> snapshot;

  @override
  Future<Map<String, dynamic>?> load() async => snapshot;

  @override
  Future<void> save(Map<String, dynamic> json) async {}
}
