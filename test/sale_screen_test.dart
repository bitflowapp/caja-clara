import 'package:b_plus_commerce/app/screens/sale_screen.dart';
import 'package:b_plus_commerce/app/services/commerce_store.dart';
import 'package:b_plus_commerce/app/widgets/commerce_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpSaleScreen(
    WidgetTester tester,
    CommerceStore store,
  ) async {
    await tester.pumpWidget(
      CommerceScope(
        store: store,
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SaleScreen(),
                        ),
                      );
                    },
                    child: const Text('Abrir venta'),
                  ),
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
      of: find.text('Guardar venta'),
      matching: find.bySubtype<ButtonStyleButton>(),
    );
    return tester.widget<ButtonStyleButton>(finder.first);
  }

  testWidgets(
    'Nueva venta exige seleccionar un producto y guarda despues del tap explicito',
    (tester) async {
      final store = CommerceStore.seededForTest();
      final initialMovements = store.movements.length;
      final initialStock = store.productById('p-1')!.stockUnits;

      await pumpSaleScreen(tester, store);

      final searchField = find.widgetWithText(TextFormField, 'Buscar producto');
      await tester.enterText(searchField, 'Yerba premium');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('8 u.'), findsOneWidget);
      expect(find.text('Debes seleccionar un producto.'), findsOneWidget);
      expect(find.text('Sin seleccionar'), findsOneWidget);
      expect(saveButton(tester).onPressed, isNull);

      await tester.tap(find.text('8 u.'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Producto seleccionado'), findsOneWidget);
      expect(find.text('Yerba premium'), findsWidgets);
      expect(saveButton(tester).onPressed, isNotNull);

      await tester.ensureVisible(find.text('Guardar venta'));
      await tester.tap(find.text('Guardar venta'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(store.movements.length, initialMovements + 1);
      expect(store.productById('p-1')!.stockUnits, initialStock - 1);
      expect(find.text('Venta guardada. Caja y stock al dia.'), findsOneWidget);
    },
  );

  testWidgets(
    'editar el texto despues de seleccionar invalida la venta y muestra que no hay coincidencias',
    (tester) async {
      final store = CommerceStore.seededForTest();

      await pumpSaleScreen(tester, store);

      final searchField = find.widgetWithText(TextFormField, 'Buscar producto');
      await tester.enterText(searchField, 'Yerba premium');
      await tester.pump();
      await tester.tap(find.text('8 u.'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Producto seleccionado'), findsOneWidget);
      expect(saveButton(tester).onPressed, isNotNull);

      await tester.enterText(searchField, 'zzzz');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Sin seleccionar'), findsOneWidget);
      expect(find.text('No se encontraron productos.'), findsOneWidget);
      expect(find.text('No se encontraron productos'), findsOneWidget);
      expect(saveButton(tester).onPressed, isNull);
    },
  );

  testWidgets(
    'venta libre guarda sin producto seleccionado y no necesita catalogo',
    (tester) async {
      final store = CommerceStore.emptyForTest();
      final initialCash = store.cashBalancePesos;
      final initialMovements = store.movements.length;

      await pumpSaleScreen(tester, store);

      await tester.ensureVisible(find.byKey(const Key('sale-mode-quick')));
      await tester.tap(find.byKey(const Key('sale-mode-quick')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Todavia no hay productos cargados'), findsNothing);
      expect(saveButton(tester).onPressed, isNull);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Descripcion'),
        'Preservativos mostrador',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Precio unitario'),
        '2500',
      );
      await tester.pump();

      expect(find.text('Venta libre'), findsWidgets);
      expect(find.text('No aplica'), findsOneWidget);
      expect(saveButton(tester).onPressed, isNotNull);

      await tester.ensureVisible(find.text('Guardar venta'));
      await tester.tap(find.text('Guardar venta'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(store.movements.length, initialMovements + 1);
      expect(store.cashBalancePesos, initialCash + 2500);
      expect(store.movements.first.isFreeSale, isTrue);
      expect(store.movements.first.subtitle, 'Preservativos mostrador');
      expect(find.text('Venta libre guardada. Caja al dia.'), findsOneWidget);
    },
  );

  testWidgets(
    'venta libre permite abrir alta de producto con descripcion y precio precargados',
    (tester) async {
      final store = CommerceStore.emptyForTest();

      await pumpSaleScreen(tester, store);

      await tester.ensureVisible(find.byKey(const Key('sale-mode-quick')));
      await tester.tap(find.byKey(const Key('sale-mode-quick')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Descripcion'),
        'Cable USB mostrador',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Precio unitario'),
        '3900',
      );
      await tester.pump();

      await tester.tap(find.text('Crear producto con estos datos'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Agregar producto'), findsOneWidget);
      expect(find.text('Cable USB mostrador'), findsWidgets);
      expect(
        find.text('Vista previa: Cable USB mostrador / \$3.900'),
        findsOneWidget,
      );
    },
  );
}
