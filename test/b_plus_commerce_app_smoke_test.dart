import 'package:b_plus_commerce/app/b_plus_commerce_app.dart';
import 'package:b_plus_commerce/app/services/commerce_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Home renders branding and primary actions', (tester) async {
    final store = CommerceStore.seededForTest();
    await tester.pumpWidget(BPlusCommerceApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text('Caja Clara'), findsWidgets);
    expect(find.text('Nueva venta'), findsOneWidget);
    expect(find.text('Cargar producto'), findsOneWidget);
    expect(find.text('Ver caja del día'), findsOneWidget);
    expect(find.text('Registrar gasto'), findsOneWidget);
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
    expect(find.text('Cargar Kiosco argentino'), findsOneWidget);
    expect(find.text('Cargar producto manualmente'), findsOneWidget);
    expect(find.text('Probá con datos de demo'), findsNothing);
    expect(find.text('Cargar datos de demo'), findsNothing);
  });

  testWidgets(
    'Home KPI "Caja del día" matches apertura + ventas - gastos',
    (tester) async {
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

      expect(find.text('Caja del día'), findsWidgets);
      expect(find.text('Caja actual'), findsNothing);
      // 10.000 apertura + 2.500 ventas - 0 gastos = 12.500
      expect(find.text(r'$12.500'), findsWidgets);
    },
  );

  testWidgets(
    'Home KPI shows "Sin apertura" when caja is not opened today',
    (tester) async {
      final store = CommerceStore.emptyForTest();
      await tester.pumpWidget(BPlusCommerceApp(store: store));
      await tester.pumpAndSettle();

      expect(find.text('Caja del día'), findsWidgets);
      expect(find.text('Sin apertura'), findsWidgets);
    },
  );
}
