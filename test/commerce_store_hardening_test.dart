import 'package:b_plus_commerce/app/services/backup_service.dart';
import 'package:b_plus_commerce/app/services/commerce_persistence.dart';
import 'package:b_plus_commerce/app/services/commerce_store.dart';
import 'package:b_plus_commerce/app/models/product.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CommerceStore hardening', () {
    test('rejects sale when stock is insufficient', () async {
      final store = CommerceStore.seededForTest();

      expect(
        () => store.recordSale(
          productId: 'p-1',
          quantityUnits: 999,
          paymentMethod: 'Efectivo',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('records valid expense and rejects invalid expense', () async {
      final store = CommerceStore.seededForTest();
      final initialCash = store.cashBalancePesos;
      final initialMovements = store.movements.length;

      await store.recordExpense(
        concept: 'Limpieza',
        amountPesos: 2500,
        category: 'Insumos',
      );

      expect(store.cashBalancePesos, initialCash - 2500);
      expect(store.movements.length, initialMovements + 1);

      await expectLater(
        store.recordExpense(concept: '', amountPesos: 0, category: 'General'),
        throwsA(isA<StateError>()),
      );
    });

    test('records free sale without touching stock and rejects invalid values', () async {
      final store = CommerceStore.seededForTest();
      final initialCash = store.cashBalancePesos;
      final initialMovements = store.movements.length;
      final initialStock = store.productById('p-1')!.stockUnits;

      await store.recordFreeSale(
        description: 'Venta mostrador',
        quantityUnits: 2,
        unitPricePesos: 1800,
        paymentMethod: 'Efectivo',
      );

      expect(store.cashBalancePesos, initialCash + 3600);
      expect(store.movements.length, initialMovements + 1);
      expect(store.productById('p-1')!.stockUnits, initialStock);
      expect(store.movements.first.isFreeSale, isTrue);
      expect(store.movements.first.subtitle, 'Venta mostrador');

      await expectLater(
        store.recordFreeSale(
          description: '',
          quantityUnits: 0,
          unitPricePesos: 0,
          paymentMethod: 'Efectivo',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('creating product after free sale keeps historical movement untouched', () async {
      final store = CommerceStore.emptyForTest();

      await store.recordFreeSale(
        description: 'Cable USB rapido',
        quantityUnits: 1,
        unitPricePesos: 4500,
        paymentMethod: 'Transferencia',
      );

      final freeSale = store.movements.first;

      await store.addProduct(
        const Product(
          id: 'p-cable',
          name: 'Cable USB rapido',
          stockUnits: 6,
          minStockUnits: 1,
          costPesos: 2200,
          pricePesos: 4500,
          category: 'Mostrador',
        ),
      );

      expect(store.productById('p-cable'), isNotNull);
      expect(store.productById('p-cable')!.stockUnits, 6);
      expect(store.movements.first.id, freeSale.id);
      expect(store.movements.first.isFreeSale, isTrue);
      expect(store.movements.first.productId, isNull);
      expect(store.movements.first.subtitle, 'Cable USB rapido');
    });

    test('suggests repeated free sale descriptions and allows dismiss', () async {
      final store = CommerceStore.emptyForTest();

      for (var i = 0; i < 3; i++) {
        await store.recordFreeSale(
          description: 'Encendedor comun',
          quantityUnits: 1,
          unitPricePesos: 1200,
          paymentMethod: 'Efectivo',
        );
      }

      expect(store.freeSaleSuggestions, hasLength(1));
      expect(store.freeSaleSuggestions.first.description, 'Encendedor comun');
      expect(store.freeSaleSuggestions.first.count, 3);

      await store.dismissFreeSaleSuggestion('Encendedor comun');

      expect(store.freeSaleSuggestions, isEmpty);
    });

    test('does not suggest repeated free sale if a matching product already exists', () async {
      final store = CommerceStore.emptyForTest();

      await store.addProduct(
        const Product(
          id: 'p-existing',
          name: 'Encendedor comun',
          stockUnits: 4,
          minStockUnits: 1,
          costPesos: 600,
          pricePesos: 1200,
          category: 'Mostrador',
        ),
      );

      for (var i = 0; i < 3; i++) {
        await store.recordFreeSale(
          description: '  encendedor   comun ',
          quantityUnits: 1,
          unitPricePesos: 1200,
          paymentMethod: 'Efectivo',
        );
      }

      expect(store.freeSaleSuggestions, isEmpty);
    });

    test('undo last sale restores stock and movement count', () async {
      final store = CommerceStore.seededForTest();
      final initialStock = store.productById('p-2')!.stockUnits;
      final initialMovements = store.movements.length;

      await store.recordSale(
        productId: 'p-2',
        quantityUnits: 1,
        paymentMethod: 'Efectivo',
      );

      expect(store.productById('p-2')!.stockUnits, initialStock - 1);
      expect(store.movements.length, initialMovements + 1);

      await store.undoLastMovement();

      expect(store.productById('p-2')!.stockUnits, initialStock);
      expect(store.movements.length, initialMovements);
    });

    test('rolls back in-memory changes when persistence fails', () async {
      final store = CommerceStore.withPersistenceForTest(
        _FailingPersistence(),
        seedDemoData: true,
      );
      final initialProducts = store.products.length;

      await expectLater(
        store.addProduct(
          const Product(
            id: 'p-fail',
            name: 'Producto temporal',
            stockUnits: 1,
            minStockUnits: 0,
            costPesos: 100,
            pricePesos: 200,
          ),
        ),
        throwsA(isA<Exception>()),
      );

      expect(store.products.length, initialProducts);
      expect(store.productById('p-fail'), isNull);
      expect(store.lastError, 'No se pudo guardar el cambio.');
    });
  });

  group('BackupService', () {
    test('builds export json with expected sections', () {
      final store = CommerceStore.seededForTest();
      final service = BackupService();
      final json = service.buildBackupJson(
        store,
        generatedAt: DateTime(2026, 3, 20, 11, 0),
      );
      final parsed = service.parseBackupJson(json);

      expect(parsed['products'], isA<List<dynamic>>());
      expect(parsed['movements'], isA<List<dynamic>>());
      expect(parsed['savedAt'], isNotNull);
      expect(parsed['backupGeneratedAt'], isNotNull);
    });

    test(
      'restore snapshot rebuilds products movements and cash session',
      () async {
        final source = CommerceStore.seededForTest();
        await source.registerCashOpening(openingBalancePesos: 50000);
        await source.recordExpense(
          concept: 'Flete',
          amountPesos: 1800,
          category: 'Logistica',
        );
        final snapshot = source.buildSnapshot(
          generatedAt: DateTime(2026, 3, 20, 12, 0),
        );

        final restored = CommerceStore.seededForTest();
        await restored.restoreSnapshot(snapshot);

        expect(restored.products.length, source.products.length);
        expect(restored.cashBalancePesos, source.cashBalancePesos);
        expect(restored.todayOpeningCashPesos, 50000);
        expect(restored.movements.first.title, 'Restauracion de backup');
        expect(restored.movements.length, source.movements.length + 1);
      },
    );
  });
}

class _FailingPersistence extends CommercePersistence {
  @override
  Future<void> save(Map<String, dynamic> json) async {
    throw Exception('disk full');
  }
}
