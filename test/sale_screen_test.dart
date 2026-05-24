import 'package:b_plus_commerce/app/models/product.dart';
import 'package:b_plus_commerce/app/screens/sale_screen.dart';
import 'package:b_plus_commerce/app/services/commerce_store.dart';
import 'package:b_plus_commerce/app/widgets/commerce_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpSaleScreen(
    WidgetTester tester,
    CommerceStore store, {
    Product? initialProduct,
  }) async {
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
                                      builder: (_) => SaleScreen(
                                        initialProduct: initialProduct,
                                      ),
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

  Finder saveButtonFinder() => find
      .ancestor(
        of: find.text('Registrar venta'),
        matching: find.bySubtype<ButtonStyleButton>(),
      )
      .first;

  ButtonStyleButton saveButton(WidgetTester tester) {
    return tester.widget<ButtonStyleButton>(saveButtonFinder());
  }

  testWidgets('quick sale starts empty and requires explicit valid input', (
    tester,
  ) async {
    final store = CommerceStore.emptyForTest();

    await pumpSaleScreen(tester, store);

    expect(find.text('Nueva venta'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Producto o detalle'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Cantidad'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Precio'), findsOneWidget);
    expect(find.text('Buscar producto'), findsNothing);
    expect(saveButton(tester).onPressed, isNull);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Producto o detalle'),
      'Agua mineral 500 ml',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Precio'), '2500');
    await tester.pump();

    expect(find.text(r'$ 2.500'), findsWidgets);
    expect(saveButton(tester).onPressed, isNotNull);
  });

  testWidgets('quick sale saves without catalog dependency', (tester) async {
    final store = CommerceStore.emptyForTest();
    final initialCash = store.cashBalancePesos;
    final initialMovements = store.movements.length;

    await pumpSaleScreen(tester, store);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Producto o detalle'),
      'Agua mineral 500 ml',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Precio'), '2500');
    await tester.pump();

    await tester.ensureVisible(saveButtonFinder());
    await tester.tap(saveButtonFinder());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(store.movements.length, initialMovements + 1);
    expect(store.cashBalancePesos, initialCash + 2500);
    expect(store.movements.first.isFreeSale, isTrue);
    expect(store.movements.first.subtitle, 'Agua mineral 500 ml');
    expect(find.text('Venta registrada.'), findsOneWidget);
  });

  testWidgets('sale opened from a product records catalog sale and updates stock', (
    tester,
  ) async {
    final store = CommerceStore.seededForTest();
    final product = store.productById('p-1')!;
    final initialMovements = store.movements.length;
    final initialStock = product.stockUnits;

    await pumpSaleScreen(tester, store, initialProduct: product);

    expect(find.text(product.name), findsWidgets);
    expect(find.text(formatProductPrice(product.pricePesos)), findsNothing);
    expect(saveButton(tester).onPressed, isNotNull);

    await tester.ensureVisible(saveButtonFinder());
    await tester.tap(saveButtonFinder());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(store.movements.length, initialMovements + 1);
    expect(store.movements.first.title, 'Venta');
    expect(store.movements.first.productId, product.id);
    expect(store.productById(product.id)!.stockUnits, initialStock - 1);
    expect(find.text('Venta registrada.'), findsOneWidget);
  });

  testWidgets('new sale uses cash by default when there is no history', (
    tester,
  ) async {
    final store = CommerceStore.emptyForTest();

    await pumpSaleScreen(tester, store);

    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    expect(find.text('Efectivo'), findsOneWidget);
  });

  testWidgets('new sale keeps a recovered non-default payment method', (
    tester,
  ) async {
    final store = CommerceStore.emptyForTest();
    await store.recordFreeSale(
      description: 'Cable USB',
      quantityUnits: 1,
      unitPricePesos: 4500,
      paymentMethod: '  Mercado Pago  ',
    );

    await pumpSaleScreen(tester, store);

    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    expect(find.text('Mercado Pago'), findsOneWidget);
  });
}

String formatProductPrice(int value) => r'$ ' + value.toString();
