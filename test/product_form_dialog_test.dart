import 'package:b_plus_commerce/app/services/commerce_store.dart';
import 'package:b_plus_commerce/app/widgets/commerce_scope.dart';
import 'package:b_plus_commerce/app/widgets/product_form_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpProductDialog(
    WidgetTester tester,
    CommerceStore store, {
    ProductEditorSeed? seed,
  }) async {
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
                      showProductEditor(context, store, seed: seed);
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
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('warns when a product with the same normalized name already exists', (
    tester,
  ) async {
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

    await tester.ensureVisible(find.text('Guardar'));
    await tester.tap(find.text('Guardar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Ya existe un producto con ese nombre'), findsOneWidget);

    await tester.tap(find.text('Usar existente'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(store.products.length, initialCount);
  });
}
