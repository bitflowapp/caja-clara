import 'package:b_plus_commerce/app/b_plus_commerce_app.dart';
import 'package:b_plus_commerce/app/services/barcode_lookup_service.dart';
import 'package:b_plus_commerce/app/services/commerce_store.dart';
import 'package:b_plus_commerce/app/models/product.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> dismissTutorialIfVisible(WidgetTester tester) async {
    if (find.text('Primeros pasos').evaluate().isEmpty) {
      return;
    }
    await tester.tap(find.text('Saltear'));
    await tester.pumpAndSettle();
  }

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
    expect(find.text('Abrir caja'), findsWidgets);
    expect(find.text('Registrar gasto'), findsOneWidget);
    expect(find.text('Escanear producto'), findsOneWidget);
    expect(find.text('Agregar producto'), findsWidgets);
    expect(find.text('Ver stock bajo'), findsOneWidget);
    expect(find.text('Ultimos movimientos'), findsOneWidget);
  });

  testWidgets('first use shows start choice and tutorial stays in help', (
    tester,
  ) async {
    final store = CommerceStore.emptyForTest();
    await tester.pumpWidget(
      BPlusCommerceApp(
        store: store,
        barcodeLookupService: const DisabledBarcodeLookupService(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Abri caja'), findsNothing);
    expect(find.text('Como quieres empezar?'), findsOneWidget);
    expect(find.text('Empezar vacio'), findsWidgets);
    expect(find.text('Probar con ejemplo'), findsWidgets);
    expect(find.text('Primero abre caja'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Como quieres empezar?')).dy,
      lessThan(tester.getTopLeft(find.text('Primero abre caja')).dy),
    );

    await tester.ensureVisible(find.text('Primeros pasos'));
    await tester.tap(find.text('Primeros pasos'));
    await tester.pumpAndSettle();

    expect(
      find.text('En menos de un minuto ya se entiende como usarla.'),
      findsOneWidget,
    );
    expect(find.text('Abri caja'), findsWidgets);
  });

  testWidgets('Home guides first use with empty or example start paths', (
    tester,
  ) async {
    final store = CommerceStore.emptyForTest();
    await tester.pumpWidget(
      BPlusCommerceApp(
        store: store,
        barcodeLookupService: const DisabledBarcodeLookupService(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Como quieres empezar?'), findsOneWidget);
    expect(find.text('Empezar vacio'), findsWidgets);
    expect(find.text('Probar con ejemplo'), findsWidgets);
  });

  testWidgets('Home keeps catalog status honest when products are incomplete', (
    tester,
  ) async {
    final store = CommerceStore.emptyForTest();
    await store.addProduct(
      const Product(
        id: 'p-1',
        name: 'Producto sin completar',
        stockUnits: 4,
        minStockUnits: 1,
        costPesos: 1000,
        pricePesos: 0,
        barcode: '7791234500097',
      ),
    );

    await tester.pumpWidget(
      BPlusCommerceApp(
        store: store,
        barcodeLookupService: const DisabledBarcodeLookupService(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Catalogo listo para vender'), findsNothing);
    expect(find.text('Productos para completar'), findsOneWidget);
    expect(find.text('Sin codigo'), findsWidgets);
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
      await dismissTutorialIfVisible(tester);

      expect(find.text('Probar con ejemplo'), findsNothing);
      expect(find.text('Cargar base simple'), findsNothing);
      expect(find.text('Agregar producto'), findsWidgets);
    },
  );
}
