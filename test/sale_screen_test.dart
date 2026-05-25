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
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      CommerceScope(
        store: store,
        child: MaterialApp(home: SaleScreen(initialProduct: initialProduct)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Finder checkoutButtonFinder() => find
      .ancestor(
        of: find.text('Registrar venta'),
        matching: find.bySubtype<ButtonStyleButton>(),
      )
      .first;

  ButtonStyleButton checkoutButton(WidgetTester tester) {
    return tester.widget<ButtonStyleButton>(checkoutButtonFinder());
  }

  TextFormField textFormFieldByLabel(WidgetTester tester, String label) {
    return tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, label),
    );
  }

  Future<void> openProductEditorFromSale(WidgetTester tester) async {
    await tester.tap(find.text('Nuevo producto'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
  }

  Future<void> openAdvancedProductOptions(WidgetTester tester) async {
    if (find.text('Ver mas opciones').evaluate().isEmpty) {
      return;
    }
    await tester.ensureVisible(find.text('Ver mas opciones'));
    await tester.tap(find.text('Ver mas opciones'));
    await tester.pump();
  }

  Future<void> saveVisibleProductForm(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Guardar producto'));
    await tester.tap(find.text('Guardar producto'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> acceptAddCreatedProductToCart(WidgetTester tester) async {
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Agregar'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('sale screen starts as a fast cart flow', (tester) async {
    final store = CommerceStore.emptyForTest();

    await pumpSaleScreen(tester, store);

    expect(find.text('Nueva venta'), findsOneWidget);
    expect(
      find.widgetWithText(TextField, 'Escaner USB o codigo'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextField, 'Buscar producto'), findsOneWidget);
    expect(find.text('Carrito vacio'), findsOneWidget);
    expect(find.text('Producto o detalle'), findsNothing);
    expect(checkoutButton(tester).onPressed, isNull);
  });

  testWidgets('search adds a product to cart and checkout records sale', (
    tester,
  ) async {
    final store = CommerceStore.seededForTest();
    final product = store.products.firstWhere((item) => item.pricePesos > 0);
    final initialMovements = store.movements.length;
    final initialStock = product.stockUnits;

    await pumpSaleScreen(tester, store);

    await tester.enterText(
      find.widgetWithText(TextField, 'Buscar producto'),
      product.name,
    );
    await tester.pump();

    await tester.tap(find.text('Agregar').first);
    await tester.pump();

    expect(find.text(product.name), findsWidgets);
    expect(checkoutButton(tester).onPressed, isNotNull);

    await tester.ensureVisible(checkoutButtonFinder());
    checkoutButton(tester).onPressed?.call();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(store.movements.length, initialMovements + 1);
    expect(store.movements.first.title, 'Venta');
    expect(store.movements.first.productId, product.id);
    expect(store.productById(product.id)!.stockUnits, initialStock - 1);
    expect(store.productById(product.id)!.soldCount, product.soldCount + 1);
    expect(find.textContaining('Venta registrada'), findsOneWidget);
  });

  testWidgets(
    'manual product creation from sale screen is immediately sellable',
    (tester) async {
      final store = CommerceStore.emptyForTest();

      await pumpSaleScreen(tester, store);
      await openProductEditorFromSale(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre'),
        'Coca-Cola 2.25L',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Precio'),
        '3500',
      );
      await openAdvancedProductOptions(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Categoria'),
        'Soda',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Codigo de barras'),
        '7790001000011',
      );

      await saveVisibleProductForm(tester);

      final product = store.productByBarcode('7790001000011');
      expect(product, isNotNull);
      expect(product!.name, 'Coca-Cola 2.25L');
      expect(product.category, 'Soda');
      expect(product.pricePesos, 3500);
      expect(product.stockUnits, greaterThan(0));

      await acceptAddCreatedProductToCart(tester);
      expect(find.text('Coca-Cola 2.25L'), findsWidgets);

      await tester.ensureVisible(checkoutButtonFinder());
      checkoutButton(tester).onPressed?.call();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(store.movements.first.title, 'Venta');
      expect(store.movements.first.productId, product.id);
      expect(store.productById(product.id)!.soldCount, 1);
      expect(store.productById(product.id)!.stockUnits, product.stockUnits - 1);
    },
  );

  testWidgets('unknown scanner barcode opens product form prefilled', (
    tester,
  ) async {
    final store = CommerceStore.emptyForTest();

    await pumpSaleScreen(tester, store);

    await tester.enterText(
      find.widgetWithText(TextField, 'Escaner USB o codigo'),
      '991122334455',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));

    await openAdvancedProductOptions(tester);

    expect(
      textFormFieldByLabel(tester, 'Codigo de barras').controller?.text,
      '991122334455',
    );
  });

  testWidgets('manual product creation rejects missing positive price', (
    tester,
  ) async {
    final store = CommerceStore.emptyForTest();

    await pumpSaleScreen(tester, store);
    await openProductEditorFromSale(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre'),
      'Producto sin precio',
    );
    await saveVisibleProductForm(tester);

    expect(find.text('El precio debe ser mayor a 0.'), findsOneWidget);
    expect(store.products, isEmpty);
  });

  testWidgets('daily summary shows sales expenses net and sale count', (
    tester,
  ) async {
    final store = CommerceStore.emptyForTest();
    await store.registerCashOpening(openingBalancePesos: 10000);
    await store.addProduct(
      const Product(
        id: 'p-coke',
        name: 'Coca-Cola 2.25L',
        category: 'Soda',
        stockUnits: 10,
        minStockUnits: 0,
        costPesos: 0,
        pricePesos: 3500,
        barcode: '7790001000011',
      ),
    );
    await store.recordSale(
      productId: 'p-coke',
      quantityUnits: 1,
      paymentMethod: 'Efectivo',
    );
    await store.recordExpense(
      concept: 'Supplier',
      category: 'Supplier',
      amountPesos: 5000,
    );

    await pumpSaleScreen(tester, store);

    await tester.tap(find.text('Cierre').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Ventas'), findsOneWidget);
    expect(find.text(r'$ 3.500'), findsOneWidget);
    expect(find.text('Gastos'), findsOneWidget);
    expect(find.text(r'$ 5.000'), findsOneWidget);
    expect(find.text('Neto'), findsOneWidget);
    expect(find.text(r'-$ 1.500'), findsOneWidget);
    expect(find.text('Cantidad de ventas'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Caja del dia'), findsOneWidget);
    expect(find.text(r'$ 8.500'), findsOneWidget);
  });

  testWidgets('sale opened from a product starts with that product in cart', (
    tester,
  ) async {
    final store = CommerceStore.seededForTest();
    final product = store.productById('p-1')!;
    final initialMovements = store.movements.length;
    final initialStock = product.stockUnits;

    await pumpSaleScreen(tester, store, initialProduct: product);

    expect(find.text(product.name), findsWidgets);
    expect(checkoutButton(tester).onPressed, isNotNull);

    await tester.ensureVisible(checkoutButtonFinder());
    checkoutButton(tester).onPressed?.call();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(store.movements.length, initialMovements + 1);
    expect(store.movements.first.title, 'Venta');
    expect(store.movements.first.productId, product.id);
    expect(store.productById(product.id)!.stockUnits, initialStock - 1);
    expect(find.textContaining('Venta registrada'), findsOneWidget);
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
