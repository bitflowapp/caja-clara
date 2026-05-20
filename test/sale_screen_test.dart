import 'package:b_plus_commerce/app/screens/sale_screen.dart';
import 'package:b_plus_commerce/app/services/commerce_store.dart';
import 'package:b_plus_commerce/app/widgets/commerce_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpSaleScreen(WidgetTester tester, CommerceStore store) async {
    final savedMessage = ValueNotifier<String?>(null);
    addTearDown(savedMessage.dispose);

    await tester.pumpWidget(
      CommerceScope(
        store: store,
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ValueListenableBuilder<String?>(
                  valueListenable: savedMessage,
                  builder: (context, message, _) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FilledButton(
                            onPressed: () async {
                              final result = await Navigator.of(context)
                                  .push<String>(
                                    MaterialPageRoute<String>(
                                      builder: (_) => const SaleScreen(),
                                    ),
                                  );
                              savedMessage.value = result;
                            },
                            child: const Text('Abrir venta'),
                          ),
                          if (message != null) ...[
                            const SizedBox(height: 12),
                            Text(message),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir venta'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  ButtonStyleButton saveButton(WidgetTester tester) {
    final finder = find.ancestor(
      of: find.text('Registrar venta'),
      matching: find.bySubtype<ButtonStyleButton>(),
    );
    return tester.widget<ButtonStyleButton>(finder.first);
  }

  testWidgets('Nueva venta es venta libre directa, sin modo Catálogo', (
    tester,
  ) async {
    final store = CommerceStore.seededForTest();

    await pumpSaleScreen(tester, store);

    expect(find.text('Registrar venta'), findsWidgets);
    expect(find.text('Catálogo'), findsNothing);
    expect(find.textContaining('catálogo'), findsNothing);
    expect(find.text('Buscar producto'), findsNothing);
    expect(
      find.widgetWithText(TextFormField, 'Producto o detalle'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextFormField, 'Cantidad'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Precio'), findsOneWidget);
  });

  testWidgets('registra una venta libre válida y actualiza la caja', (
    tester,
  ) async {
    final store = CommerceStore.emptyForTest();
    final initialCash = store.cashBalancePesos;
    final initialMovements = store.movements.length;

    await pumpSaleScreen(tester, store);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Producto o detalle'),
      'Alfajor triple',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Precio'),
      '1500',
    );
    await tester.pump();

    expect(saveButton(tester).onPressed, isNotNull);

    await tester.ensureVisible(find.text('Registrar venta'));
    await tester.tap(find.text('Registrar venta'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(store.movements.length, initialMovements + 1);
    expect(store.cashBalancePesos, initialCash + 1500);
    expect(store.movements.first.isFreeSale, isTrue);
    expect(store.movements.first.subtitle, 'Alfajor triple');
    expect(find.text('Venta registrada.'), findsOneWidget);
  });

  testWidgets('no permite guardar sin descripción', (tester) async {
    final store = CommerceStore.emptyForTest();

    await pumpSaleScreen(tester, store);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Precio'),
      '900',
    );
    await tester.pump();

    expect(saveButton(tester).onPressed, isNull);
  });

  testWidgets('no permite guardar con precio inválido', (tester) async {
    final store = CommerceStore.emptyForTest();

    await pumpSaleScreen(tester, store);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Producto o detalle'),
      'Gaseosa 500 ml',
    );
    await tester.pump();

    // Sin precio cargado, no se puede guardar.
    expect(saveButton(tester).onPressed, isNull);
  });

  testWidgets('no permite guardar con cantidad en cero', (tester) async {
    final store = CommerceStore.emptyForTest();

    await pumpSaleScreen(tester, store);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Producto o detalle'),
      'Café',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Precio'),
      '2000',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Cantidad'),
      '0',
    );
    await tester.pump();

    expect(saveButton(tester).onPressed, isNull);
  });

  testWidgets('usa efectivo por defecto cuando no hay historial previo', (
    tester,
  ) async {
    final store = CommerceStore.emptyForTest();

    await pumpSaleScreen(tester, store);

    expect(find.text('Efectivo'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Cantidad'), findsOneWidget);
  });
}
