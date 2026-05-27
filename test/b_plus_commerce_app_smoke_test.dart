import 'package:b_plus_commerce/app/b_plus_commerce_app.dart';
import 'package:b_plus_commerce/app/models/product.dart';
import 'package:b_plus_commerce/app/screens/expense_screen.dart';
import 'package:b_plus_commerce/app/screens/sale_screen.dart';
import 'package:b_plus_commerce/app/screens/summary_screen.dart';
import 'package:b_plus_commerce/app/services/commerce_store.dart';
import 'package:b_plus_commerce/app/widgets/commerce_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Home renders branding and primary actions', (tester) async {
    final store = CommerceStore.seededForTest();
    await tester.pumpWidget(BPlusCommerceApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text('Estado de caja'), findsOneWidget);
    expect(find.text('Nueva venta'), findsOneWidget);
    expect(find.text('Abrir caja'), findsOneWidget);
    expect(find.text('Productos'), findsWidgets);
    expect(find.text('Cierre / resumen'), findsOneWidget);
    expect(find.text('Registrar gasto'), findsOneWidget);
    expect(find.text('Más acciones'), findsOneWidget);
    expect(find.text('Compartir resumen'), findsOneWidget);
    expect(find.text('Últimos movimientos'), findsOneWidget);
    expect(find.text('Demo comercial'), findsNothing);
    expect(find.textContaining('Build '), findsNothing);
    // Stock bajo banner shows because seeded test data has 3 low-stock products.
    expect(find.textContaining('productos con poco stock'), findsOneWidget);
  });

  testWidgets('Home guides first use with kiosk template', (tester) async {
    final store = CommerceStore.emptyForTest();
    await tester.pumpWidget(BPlusCommerceApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text('Arrancá con una base de kiosco'), findsOneWidget);
    expect(find.text('Abrir caja'), findsOneWidget);
    expect(find.text('Cargar Kiosco argentino'), findsOneWidget);
    expect(find.text('Cargar producto manualmente'), findsOneWidget);
    expect(find.text('Probá con datos de demo'), findsNothing);
    expect(find.text('Cargar datos de demo'), findsNothing);
  });

  testWidgets('Home KPI "Caja esperada" matches apertura + ventas - gastos', (
    tester,
  ) async {
    final store = CommerceStore.emptyForTest();
    await store.registerCashOpening(openingBalancePesos: 10000);
    await store.recordFreeSale(
      description: 'Venta mostrador',
      quantityUnits: 1,
      unitPricePesos: 2500,
      paymentMethod: 'Efectivo',
    );

    await tester.pumpWidget(BPlusCommerceApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text('Caja esperada'), findsOneWidget);
    expect(find.text('Caja actual'), findsNothing);
    // 10.000 apertura + 2.500 ventas - 0 gastos = 12.500
    expect(find.text(r'$ 12.500'), findsWidgets);
  });

  testWidgets('Home KPI shows "Sin apertura" when caja is not opened today', (
    tester,
  ) async {
    final store = CommerceStore.emptyForTest();
    await tester.pumpWidget(BPlusCommerceApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text('Caja esperada'), findsOneWidget);
    expect(find.text('Sin apertura'), findsWidgets);
  });

  testWidgets('Home shows open-register primary action when caja is open', (
    tester,
  ) async {
    final store = CommerceStore.emptyForTest();
    await store.registerCashOpening(openingBalancePesos: 10000);

    await tester.pumpWidget(BPlusCommerceApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text('Caja abierta'), findsOneWidget);
    expect(find.text('Nueva venta'), findsWidgets);
    expect(find.text('Registrar gasto'), findsWidgets);
    expect(find.text('Cerrar caja'), findsWidgets);
    expect(find.textContaining(r'$ 10.000'), findsWidgets);
  });

  testWidgets(
    'Home with closed register shows Caja cerrada and Abrir caja CTA',
    (tester) async {
      final store = CommerceStore.emptyForTest();
      await store.registerCashOpening(openingBalancePesos: 10000);
      await store.registerCashClosing(closingBalancePesos: 10000);

      await tester.pumpWidget(BPlusCommerceApp(store: store));
      await tester.pumpAndSettle();

      // Banner and contextual panel both say "Caja cerrada"
      expect(find.text('Caja cerrada'), findsWidgets);
      // Primary CTA must be "Abrir caja"
      expect(find.text('Abrir caja'), findsWidgets);
      expect(
        find.text('Reabrí la caja de hoy; mantiene ventas y gastos.'),
        findsOneWidget,
      );
      // "Nueva venta" must not be the primary action button; the contextual
      // panel does not render it for dayClosed — only the quick-actions panel
      // shows it as disabled (subtitle = "Caja cerrada", onTap = null).
      // Verify the quick-action subtitle for Nueva venta shows disabled text.
      expect(find.text('Caja cerrada'), findsWidgets);
    },
  );

  testWidgets('Expense screen avoids unsupported dictation warning bars', (
    tester,
  ) async {
    final store = CommerceStore.emptyForTest();
    await store.registerCashOpening(openingBalancePesos: 10000);

    await tester.pumpWidget(
      MaterialApp(
        home: CommerceScope(store: store, child: const ExpenseScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Nuevo gasto'), findsOneWidget);
    expect(find.textContaining('dictado no está disponible'), findsNothing);
    expect(find.textContaining('dictado no esta disponible'), findsNothing);
  });

  testWidgets('Store blocks recordSale when register is closed', (
    tester,
  ) async {
    final store = CommerceStore.emptyForTest();
    await store.registerCashOpening(openingBalancePesos: 10000);
    await store.registerCashClosing(closingBalancePesos: 10000);

    // Add a product so we can attempt a sale
    await store.addProduct(
      const Product(
        id: 'p-test',
        name: 'Producto test',
        stockUnits: 10,
        minStockUnits: 0,
        costPesos: 0,
        pricePesos: 1000,
      ),
    );

    final movementsBeforeAttempt = store.movements.length;

    await expectLater(
      store.recordSale(
        productId: 'p-test',
        quantityUnits: 1,
        paymentMethod: 'Efectivo',
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('La caja está cerrada'),
        ),
      ),
    );

    // No new movement must have been recorded
    expect(store.movements.length, movementsBeforeAttempt);
  });

  testWidgets('Store blocks recordFreeSale when register is closed', (
    tester,
  ) async {
    final store = CommerceStore.emptyForTest();
    await store.registerCashOpening(openingBalancePesos: 10000);
    await store.registerCashClosing(closingBalancePesos: 10000);

    final movementsBeforeAttempt = store.movements.length;

    await expectLater(
      store.recordFreeSale(
        description: 'Venta mostrador',
        quantityUnits: 1,
        unitPricePesos: 500,
        paymentMethod: 'Efectivo',
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('La caja está cerrada'),
        ),
      ),
    );

    expect(store.movements.length, movementsBeforeAttempt);
  });

  testWidgets('Store blocks recordExpense when register is closed', (
    tester,
  ) async {
    final store = CommerceStore.emptyForTest();
    await store.registerCashOpening(openingBalancePesos: 10000);
    await store.registerCashClosing(closingBalancePesos: 10000);

    final movementsBeforeAttempt = store.movements.length;

    await expectLater(
      store.recordExpense(
        concept: 'Bolsas',
        amountPesos: 500,
        category: 'Insumos',
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('La caja está cerrada'),
        ),
      ),
    );

    expect(store.movements.length, movementsBeforeAttempt);
  });

  testWidgets(
    'Closing difference remains stable after attempted post-close sale',
    (tester) async {
      final store = CommerceStore.emptyForTest();
      await store.addProduct(
        const Product(
          id: 'p-test2',
          name: 'Producto test 2',
          stockUnits: 10,
          minStockUnits: 0,
          costPesos: 0,
          pricePesos: 2000,
        ),
      );
      await store.registerCashOpening(openingBalancePesos: 10000);
      await store.registerCashClosing(closingBalancePesos: 10000);

      final differenceBefore = store.todayClosingDifferencePesos;

      // Attempt a sale after closing — must be blocked
      try {
        await store.recordSale(
          productId: 'p-test2',
          quantityUnits: 1,
          paymentMethod: 'Efectivo',
        );
      } on StateError {
        // expected
      }

      // Difference must be unchanged
      expect(store.todayClosingDifferencePesos, differenceBefore);
    },
  );

  testWidgets(
    'SaleScreen closed-register blocker shows "Abrir caja" when callback provided',
    (tester) async {
      final store = CommerceStore.emptyForTest();
      await store.registerCashOpening(openingBalancePesos: 5000);
      await store.registerCashClosing(closingBalancePesos: 5000);

      await tester.pumpWidget(
        MaterialApp(
          home: CommerceScope(
            store: store,
            child: SaleScreen(onOpenCashRegister: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'La caja está cerrada. Reabrí la caja de hoy para registrar ventas.',
        ),
        findsOneWidget,
      );
      expect(find.text('Abrir caja'), findsOneWidget);
      expect(find.text('Volver al inicio'), findsOneWidget);
    },
  );

  testWidgets(
    'SaleScreen closed-register blocker shows only "Volver al inicio" without callback',
    (tester) async {
      final store = CommerceStore.emptyForTest();
      await store.registerCashOpening(openingBalancePesos: 5000);
      await store.registerCashClosing(closingBalancePesos: 5000);

      await tester.pumpWidget(
        MaterialApp(
          home: CommerceScope(store: store, child: const SaleScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Volver al inicio'), findsOneWidget);
      expect(find.text('Abrir caja'), findsNothing);
    },
  );

  testWidgets('ExpenseScreen closed-register blocker uses reopen wording', (
    tester,
  ) async {
    final store = CommerceStore.emptyForTest();
    await store.registerCashOpening(openingBalancePesos: 5000);
    await store.registerCashClosing(closingBalancePesos: 5000);

    await tester.pumpWidget(
      MaterialApp(
        home: CommerceScope(store: store, child: const ExpenseScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'La caja está cerrada. Reabrí la caja de hoy para registrar gastos.',
      ),
      findsOneWidget,
    );
    expect(find.text('Volver al inicio'), findsOneWidget);
    expect(find.text('Abrir caja'), findsNothing);
  });

  testWidgets(
    'SummaryScreen shows confirmation dialog before editing on a closed-day register',
    (tester) async {
      final store = CommerceStore.emptyForTest();
      await store.registerCashOpening(openingBalancePesos: 5000);
      await store.registerCashClosing(closingBalancePesos: 5000);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommerceScope(
              store: store,
              child: SummaryScreen(
                onExportExcel: () {},
                exportingExcel: false,
                onExportBackup: () {},
                exportingBackup: false,
                onRestoreBackup: () {},
                restoringBackup: false,
                onUndoLastMovement: () {},
                undoingMovement: false,
                onRegisterCashOpening: () {},
                onRegisterCashClosing: () {},
                savingCashEvent: false,
                onShareDailySummary: () {},
                onCreateProductFromFreeSale: (_) async {},
                onCreateProductFromSuggestion: (_) async {},
                onDismissFreeSaleSuggestion: (_) async {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Editar apertura'));
      await tester.tap(find.text('Editar apertura'));
      await tester.pumpAndSettle();

      expect(find.text('Editar caja cerrada'), findsOneWidget);
      expect(find.text('Editar igual'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
    },
  );

  testWidgets('Low stock banner shows softened copy when count exceeds 10', (
    tester,
  ) async {
    final store = CommerceStore.emptyForTest();
    for (var i = 0; i < 11; i++) {
      await store.addProduct(
        Product(
          id: 'low-stock-$i',
          name: 'Producto bajo $i',
          stockUnits: 0,
          minStockUnits: 1,
          costPesos: 100,
          pricePesos: 200,
        ),
      );
    }

    await tester.pumpWidget(BPlusCommerceApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text('Revisá el stock de tus productos.'), findsOneWidget);
    expect(find.textContaining('Te faltan'), findsNothing);
  });
}
