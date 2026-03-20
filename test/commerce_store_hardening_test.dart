import 'package:b_plus_commerce/app/services/backup_service.dart';
import 'package:b_plus_commerce/app/services/commerce_store.dart';
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
        store.recordExpense(
          concept: '',
          amountPesos: 0,
          category: 'General',
        ),
        throwsA(isA<StateError>()),
      );
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

    test('restore snapshot rebuilds products movements and cash session', () async {
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
    });
  });
}
