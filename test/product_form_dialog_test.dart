import 'package:b_plus_commerce/app/models/product.dart';
import 'package:b_plus_commerce/app/services/commerce_store.dart';
import 'package:b_plus_commerce/app/widgets/commerce_scope.dart';
import 'package:b_plus_commerce/app/widgets/product_form_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpProductDialog(
    WidgetTester tester,
    CommerceStore store, {
    Product? product,
    ProductEditorSeed? seed,
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

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
                      showProductEditor(
                        context,
                        store,
                        product: product,
                        seed: seed,
                      );
                    },
                    child: const Text('Abrir producto'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir producto'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
  }

  testWidgets(
    'warns when a product with the same normalized name already exists',
    (tester) async {
      final store = CommerceStore.seededForTest();
      final initialCount = store.products.length;

      await pumpProductDialog(
        tester,
        store,
        seed: const ProductEditorSeed(
          name: '  yerba   premium  ',
          pricePesos: 4100,
        ),
      );

      await tester.ensureVisible(find.text('Guardar producto'));
      await tester.tap(find.text('Guardar producto'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Ya existe un producto con ese nombre'), findsOneWidget);

      await tester.tap(find.text('Usar existente'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(store.products.length, initialCount);
      expect(find.byType(SnackBar), findsNothing);
    },
  );

  testWidgets(
    'saving a new product closes the dialog without an extra snackbar',
    (tester) async {
      final store = CommerceStore.emptyForTest();

      await pumpProductDialog(
        tester,
        store,
        seed: const ProductEditorSeed(
          name: 'Cable lightning',
          pricePesos: 8900,
        ),
      );

      await tester.ensureVisible(find.text('Guardar producto'));
      await tester.tap(find.text('Guardar producto'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(store.products, hasLength(1));
      expect(store.products.single.name, 'Cable lightning');
      expect(find.text('Agregar producto'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    },
  );

  testWidgets('warns when a product with the same barcode already exists', (
    tester,
  ) async {
    final store = CommerceStore.seededForTest();
    final initialCount = store.products.length;

    await pumpProductDialog(
      tester,
      store,
      seed: const ProductEditorSeed(
        name: 'Yerba mostrador',
        pricePesos: 4100,
        barcode: ' 7791-2345_00011 ',
      ),
    );

    await tester.ensureVisible(find.text('Guardar producto'));
    await tester.tap(find.text('Guardar producto'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Ese codigo ya esta en otro producto'), findsOneWidget);

    await tester.tap(find.text('Usar existente'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(store.products.length, initialCount);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets(
    'warns when editing a product into the exact name of another one',
    (tester) async {
      final store = CommerceStore.seededForTest();
      final product = store.productById('p-2')!;

      await pumpProductDialog(
        tester,
        store,
        product: product,
        size: const Size(1100, 900),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre'),
        'Yerba premium',
      );
      await tester.pump();

      await tester.ensureVisible(find.text('Guardar producto'));
      await tester.tap(find.text('Guardar producto'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.text('Ya existe otro producto con ese nombre'),
        findsOneWidget,
      );

      await tester.tap(find.text('Usar existente'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(store.productById('p-2')?.name, 'Papel higienico x4');
    },
  );

  testWidgets(
    'uses fullscreen form on narrow screens and dialog on wide screens',
    (tester) async {
      final mobileStore = CommerceStore.emptyForTest();
      await pumpProductDialog(tester, mobileStore);

      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Agregar producto'), findsWidgets);
      expect(find.widgetWithText(TextFormField, 'Nombre'), findsNothing);
      expect(find.text('Toca para cargar el nombre'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));

      final desktopStore = CommerceStore.emptyForTest();
      await pumpProductDialog(
        tester,
        desktopStore,
        size: const Size(1100, 900),
      );

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Nombre'), findsOneWidget);
      expect(find.text('Ver mas opciones'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Categoria'), findsNothing);
    },
  );

  testWidgets('desktop product form keeps extras hidden by default', (
    tester,
  ) async {
    final store = CommerceStore.emptyForTest();

    await pumpProductDialog(tester, store, size: const Size(1100, 900));

    expect(find.text('Lo basico'), findsOneWidget);
    expect(
      find.text('Solo necesitas nombre, precio y stock para empezar a vender.'),
      findsOneWidget,
    );
    expect(find.text('Ver mas opciones'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Categoria'), findsNothing);

    await tester.tap(find.text('Ver mas opciones'));
    await tester.pump();

    expect(find.widgetWithText(TextFormField, 'Categoria'), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, 'Codigo de barras'),
      findsOneWidget,
    );
  });
}
