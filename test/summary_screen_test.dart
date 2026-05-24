import 'package:b_plus_commerce/app/screens/summary_screen.dart';
import 'package:b_plus_commerce/app/services/commerce_store.dart';
import 'package:b_plus_commerce/app/widgets/commerce_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpSummaryScreen(
    WidgetTester tester,
    CommerceStore store,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      CommerceScope(
        store: store,
        child: MaterialApp(
          home: Scaffold(
            body: SummaryScreen(
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
              onCreateProductFromFreeSale: (_) async {},
              onCreateProductFromSuggestion: (_) async {},
              onDismissFreeSaleSuggestion: (_) async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('summary shows Luna cash dashboard and recent movements', (
    tester,
  ) async {
    final store = CommerceStore.seededForTest();

    await pumpSummaryScreen(tester, store);

    expect(find.textContaining('Caja del'), findsWidgets);
    expect(find.text('Tu caja, clara'), findsOneWidget);
    expect(find.text('Exportar Excel'), findsOneWidget);
    expect(find.textContaining('Movimientos'), findsWidgets);
    expect(find.textContaining('Apertura'), findsWidgets);
  });

  testWidgets('summary shows opening plus sales minus expenses formula', (
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

    await pumpSummaryScreen(tester, store);

    expect(find.textContaining('ventas - gastos'), findsWidgets);
    expect(find.text(r'$ 10.000'), findsWidgets);
    expect(find.text(r'$ 2.500'), findsWidgets);
    expect(find.text(r'$ 12.500'), findsWidgets);
  });
}
