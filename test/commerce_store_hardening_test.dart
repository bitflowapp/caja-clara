import 'package:b_plus_commerce/app/services/backup_service.dart';
import 'package:b_plus_commerce/app/services/commerce_persistence.dart';
import 'package:b_plus_commerce/app/services/commerce_store.dart';
import 'package:b_plus_commerce/app/services/license_service.dart';
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

    test(
      'records free sale without touching stock and rejects invalid values',
      () async {
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
      },
    );

    test(
      'creating product after free sale keeps historical movement untouched',
      () async {
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
      },
    );

    test(
      'suggests repeated free sale descriptions and allows dismiss',
      () async {
        final store = CommerceStore.emptyForTest();
        final soldAt = <DateTime>[
          DateTime(2026, 3, 20, 9, 0),
          DateTime(2026, 3, 21, 11, 30),
          DateTime(2026, 3, 23, 8, 45),
        ];
        final prices = <int>[1200, 1500, 1700];
        final quantities = <int>[1, 2, 1];

        for (var i = 0; i < 3; i++) {
          await store.recordFreeSale(
            description: 'Encendedor comun',
            quantityUnits: quantities[i],
            unitPricePesos: prices[i],
            paymentMethod: 'Efectivo',
            createdAt: soldAt[i],
          );
        }

        expect(store.freeSaleSuggestions, hasLength(1));
        expect(
          store.freeSaleSuggestions.first.normalizedDescription,
          'encendedor comun',
        );
        expect(
          store.freeSaleSuggestions.first.displayDescription,
          'Encendedor comun',
        );
        expect(store.freeSaleSuggestions.first.repeatCount, 3);
        expect(store.freeSaleSuggestions.first.latestSoldAt, soldAt.last);
        expect(store.freeSaleSuggestions.first.totalRevenuePesos, 5900);
        expect(store.freeSaleSuggestions.first.latestUnitPricePesos, 1700);

        await store.dismissFreeSaleSuggestion('Encendedor comun');

        expect(store.freeSaleSuggestions, isEmpty);
      },
    );

    test(
      'uses the newest free sale date and unit price even if inserts arrive out of order',
      () async {
        final store = CommerceStore.emptyForTest();
        final newestSaleAt = DateTime(2026, 3, 23, 19, 15);

        await store.recordFreeSale(
          description: 'Cable USB rapido',
          quantityUnits: 1,
          unitPricePesos: 4200,
          paymentMethod: 'Transferencia',
          createdAt: newestSaleAt,
        );
        await store.recordFreeSale(
          description: 'Cable USB rapido',
          quantityUnits: 1,
          unitPricePesos: 3900,
          paymentMethod: 'Transferencia',
          createdAt: DateTime(2026, 3, 21, 11, 0),
        );
        await store.recordFreeSale(
          description: 'Cable USB rapido',
          quantityUnits: 2,
          unitPricePesos: 4000,
          paymentMethod: 'Transferencia',
          createdAt: DateTime(2026, 3, 22, 17, 0),
        );

        final suggestion = store.freeSaleSuggestions.single;
        expect(suggestion.latestSoldAt, newestSaleAt);
        expect(suggestion.latestUnitPricePesos, 4200);
        expect(suggestion.totalRevenuePesos, 16100);
      },
    );

    test(
      'does not suggest repeated free sale if a matching product already exists',
      () async {
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
      },
    );

    test('remembers the last payment method used in sales', () async {
      final store = CommerceStore.emptyForTest();

      expect(store.lastSalePaymentMethod, isNull);

      await store.recordFreeSale(
        description: 'Cable USB',
        quantityUnits: 1,
        unitPricePesos: 4500,
        paymentMethod: 'Transferencia',
      );

      expect(store.lastSalePaymentMethod, 'Transferencia');
    });

    test('stores payment methods trimmed for future defaults', () async {
      final store = CommerceStore.emptyForTest();

      await store.recordFreeSale(
        description: 'Cable USB',
        quantityUnits: 1,
        unitPricePesos: 4500,
        paymentMethod: '  Mercado Pago  ',
      );

      expect(store.movements.first.paymentMethod, 'Mercado Pago');
      expect(store.lastSalePaymentMethod, 'Mercado Pago');
    });

    test(
      'builds a daily movement summary with today counts and recent items',
      () async {
        final store = CommerceStore.emptyForTest();
        final now = DateTime(2026, 3, 28, 18, 0);

        await store.recordFreeSale(
          description: 'Venta mostrador',
          quantityUnits: 1,
          unitPricePesos: 2500,
          paymentMethod: 'Efectivo',
          createdAt: now.subtract(const Duration(hours: 1)),
        );
        await store.recordExpense(
          concept: 'Bolsas',
          amountPesos: 800,
          category: 'Insumos',
          createdAt: now.subtract(const Duration(minutes: 30)),
        );
        await store.recordFreeSale(
          description: 'Venta vieja',
          quantityUnits: 1,
          unitPricePesos: 1200,
          paymentMethod: 'Efectivo',
          createdAt: now.subtract(const Duration(days: 2)),
        );

        final summary = store.dailyMovementSummary(now: now, recentLimit: 3);

        expect(summary.movementCount, 2);
        expect(summary.salesCount, 1);
        expect(summary.salesPesos, 2500);
        expect(summary.expenseCount, 1);
        expect(summary.expensesPesos, 800);
        expect(summary.recentMovements, hasLength(2));
        expect(summary.recentMovements.first.originLabel, 'Gasto');
        expect(summary.recentMovements.first.title, 'Bolsas');
      },
    );

    test('ranks top selling products for the day by units sold', () async {
      final store = CommerceStore.emptyForTest();
      final now = DateTime(2026, 3, 28, 18, 0);

      await store.addProduct(
        const Product(
          id: 'top-1',
          name: 'Yerba suave',
          stockUnits: 12,
          minStockUnits: 2,
          costPesos: 2200,
          pricePesos: 3600,
          category: 'Almacen',
        ),
      );
      await store.addProduct(
        const Product(
          id: 'top-2',
          name: 'Galletitas surtidas',
          stockUnits: 10,
          minStockUnits: 2,
          costPesos: 900,
          pricePesos: 1700,
          category: 'Almacen',
        ),
      );

      await store.recordSale(
        productId: 'top-1',
        quantityUnits: 3,
        paymentMethod: 'Efectivo',
        createdAt: now.subtract(const Duration(hours: 2)),
      );
      await store.recordSale(
        productId: 'top-2',
        quantityUnits: 1,
        paymentMethod: 'Efectivo',
        createdAt: now.subtract(const Duration(hours: 1)),
      );
      await store.recordSale(
        productId: 'top-1',
        quantityUnits: 1,
        paymentMethod: 'Transferencia',
        createdAt: now.subtract(const Duration(minutes: 20)),
      );

      final topSelling = store.topSellingProductsToday(now: now);

      expect(topSelling, hasLength(2));
      expect(topSelling.first.product.id, 'top-1');
      expect(topSelling.first.unitsSold, 4);
      expect(topSelling[1].product.id, 'top-2');
    });

    test(
      'prioritizes urgent restock when low stock also moved recently',
      () async {
        final store = CommerceStore.emptyForTest();
        final now = DateTime(2026, 3, 28, 18, 0);

        await store.addProduct(
          const Product(
            id: 'restock-hot',
            name: 'Papas fritas 100 g',
            stockUnits: 4,
            minStockUnits: 5,
            costPesos: 700,
            pricePesos: 1400,
            category: 'Golosinas',
          ),
        );
        await store.addProduct(
          const Product(
            id: 'restock-cold',
            name: 'Lavandina 1 L',
            stockUnits: 0,
            minStockUnits: 3,
            costPesos: 1200,
            pricePesos: 2100,
            category: 'Limpieza',
          ),
        );

        await store.recordSale(
          productId: 'restock-hot',
          quantityUnits: 2,
          paymentMethod: 'Efectivo',
          createdAt: now.subtract(const Duration(days: 1)),
        );

        final urgentRestock = store.urgentRestockProducts(now: now);

        expect(urgentRestock, hasLength(2));
        expect(urgentRestock.first.product.id, 'restock-hot');
        expect(urgentRestock.first.hasRecentSales, isTrue);
        expect(urgentRestock.first.recentUnitsSold, 2);
      },
    );

    test(
      'keeps low rotation honest when history is short and flags stale stock later',
      () async {
        final store = CommerceStore.emptyForTest();
        final now = DateTime(2026, 3, 28, 18, 0);

        await store.addProduct(
          const Product(
            id: 'rot-fast',
            name: 'Agua mineral 500 ml',
            stockUnits: 20,
            minStockUnits: 4,
            costPesos: 500,
            pricePesos: 1100,
            category: 'Bebidas',
          ),
        );
        await store.addProduct(
          const Product(
            id: 'rot-stale',
            name: 'Bizcochos',
            stockUnits: 14,
            minStockUnits: 3,
            costPesos: 600,
            pricePesos: 1200,
            category: 'Galletitas',
          ),
        );

        expect(store.lowRotationProducts(now: now).hasEnoughHistory, isFalse);

        for (var i = 0; i < 6; i++) {
          await store.recordSale(
            productId: 'rot-fast',
            quantityUnits: 1,
            paymentMethod: 'Efectivo',
            createdAt: now.subtract(Duration(days: 10 + i)),
          );
        }

        final lowRotation = store.lowRotationProducts(now: now);

        expect(lowRotation.hasEnoughHistory, isTrue);
        expect(lowRotation.products, hasLength(1));
        expect(lowRotation.products.first.product.id, 'rot-stale');
        expect(
          lowRotation.products.first.statusLabel,
          'Sin movimiento reciente',
        );
      },
    );

    test('persists dismissed onboarding tutorial state in snapshots', () async {
      final store = CommerceStore.emptyForTest();

      expect(store.shouldPromptOnboardingTutorial, isTrue);

      await store.dismissOnboardingTutorial();

      expect(
        store.onboardingTutorialStatus,
        OnboardingTutorialStatus.dismissed,
      );
      expect(store.shouldPromptOnboardingTutorial, isFalse);

      final snapshot = store.buildSnapshot(
        generatedAt: DateTime(2026, 3, 28, 16, 0),
      );
      final restored = CommerceStore.emptyForTest();
      await restored.restoreSnapshot(snapshot);

      expect(
        restored.onboardingTutorialStatus,
        OnboardingTutorialStatus.dismissed,
      );
      expect(restored.shouldPromptOnboardingTutorial, isFalse);
    });

    test(
      'older snapshots with data stay quiet even without onboarding status',
      () async {
        final source = CommerceStore.seededForTest();
        final snapshot = source.buildSnapshot(
          generatedAt: DateTime(2026, 3, 28, 16, 30),
        )..remove('onboardingTutorialStatus');

        final restored = CommerceStore.emptyForTest();
        await restored.restoreSnapshot(snapshot);

        expect(
          restored.onboardingTutorialStatus,
          OnboardingTutorialStatus.completed,
        );
        expect(restored.shouldPromptOnboardingTutorial, isFalse);
      },
    );

    test('blocks operational writes when the Windows trial expired', () async {
      final now = DateTime(2026, 3, 26, 10, 0);
      final store = CommerceStore.emptyForTest();
      final licenseService = LicenseService.forTest(
        clock: () => now,
        installationId: 'CCW-TEST-LOCK',
        trialStartedAt: now.subtract(const Duration(days: 31)),
      );
      store.attachLicenseService(licenseService);

      await expectLater(
        store.recordFreeSale(
          description: 'Venta mostrador',
          quantityUnits: 1,
          unitPricePesos: 2500,
          paymentMethod: 'Efectivo',
        ),
        throwsA(isA<LicenseRestrictionException>()),
      );

      expect(store.movements, isEmpty);
      expect(store.cashBalancePesos, 0);
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
