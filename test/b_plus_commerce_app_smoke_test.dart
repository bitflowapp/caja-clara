import 'package:b_plus_commerce/app/b_plus_commerce_app.dart';
import 'package:b_plus_commerce/app/services/barcode_lookup_service.dart';
import 'package:b_plus_commerce/app/services/commerce_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Home renders branding and primary actions', (tester) async {
    final store = CommerceStore.seededForTest();
    await tester.pumpWidget(
      BPlusCommerceApp(
        store: store,
        barcodeLookupService: const DisabledBarcodeLookupService(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Caja Clara'), findsWidgets);
    expect(find.text('Nueva venta'), findsOneWidget);
    expect(find.text('Registrar gasto'), findsOneWidget);
    expect(find.text('Escanear producto'), findsOneWidget);
    expect(find.text('Agregar producto'), findsOneWidget);
    expect(find.text('Ver stock bajo'), findsOneWidget);
    expect(find.text('Ultimos movimientos'), findsOneWidget);
  });

  testWidgets('Home guides first use with kiosk template', (tester) async {
    final store = CommerceStore.emptyForTest();
    await tester.pumpWidget(
      BPlusCommerceApp(
        store: store,
        barcodeLookupService: const DisabledBarcodeLookupService(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lista para demo o primer uso'), findsOneWidget);
    expect(find.text('Cargar demo comercial'), findsOneWidget);
    expect(find.text('Cargar Kiosco argentino'), findsOneWidget);
    expect(find.text('Agregar producto manualmente'), findsOneWidget);
  });

  testWidgets(
    'Home hides demo CTA when there are movements but the catalog is still empty',
    (tester) async {
      final store = CommerceStore.emptyForTest();
      await store.recordFreeSale(
        description: 'Venta mostrador',
        quantityUnits: 1,
        unitPricePesos: 2500,
        paymentMethod: 'Efectivo',
      );

      await tester.pumpWidget(
        BPlusCommerceApp(
          store: store,
          barcodeLookupService: const DisabledBarcodeLookupService(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cargar demo comercial'), findsNothing);
      expect(find.text('Cargar Kiosco argentino'), findsOneWidget);
      expect(find.text('Agregar producto manualmente'), findsOneWidget);
    },
  );
}
