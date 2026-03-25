import 'package:b_plus_commerce/app/models/product.dart';
import 'package:b_plus_commerce/app/screens/barcode_scan_screen.dart';
import 'package:b_plus_commerce/app/services/commerce_store.dart';
import 'package:b_plus_commerce/app/widgets/commerce_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpBarcodeScreen(
    WidgetTester tester,
    CommerceStore store,
  ) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      CommerceScope(
        store: store,
        child: const MaterialApp(home: BarcodeScanScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> enterManualBarcode(WidgetTester tester, String value) async {
    await tester.tap(find.text('Ingresar codigo').first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Codigo de barras'),
      value,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buscar producto'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'manual fallback resolves alphanumeric barcode',
    (tester) async {
      final store = CommerceStore.emptyForTest();
      await store.addProduct(
        const Product(
          id: 'p-alpha',
          name: 'Cable USB-C',
          stockUnits: 5,
          minStockUnits: 1,
          costPesos: 2200,
          pricePesos: 4500,
          barcode: 'ABC123',
        ),
      );

      await pumpBarcodeScreen(tester, store);
      await enterManualBarcode(tester, 'abc123');

      expect(find.text('Producto encontrado'), findsOneWidget);
      expect(find.text('Cable USB-C'), findsOneWidget);
      expect(find.text('Cod. ABC123'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'scanner sale flow preserves success feedback',
    (tester) async {
      final store = CommerceStore.emptyForTest();
      await store.addProduct(
        const Product(
          id: 'p-alpha',
          name: 'Cable USB-C',
          stockUnits: 5,
          minStockUnits: 1,
          costPesos: 2200,
          pricePesos: 4500,
          barcode: 'ABC123',
        ),
      );

      await pumpBarcodeScreen(tester, store);
      await enterManualBarcode(tester, 'ABC123');

      await tester.tap(find.text('Registrar venta'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Nueva venta'), findsOneWidget);

      await tester.ensureVisible(find.text('Guardar venta'));
      await tester.tap(find.text('Guardar venta'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Escanear producto'), findsOneWidget);
      expect(find.text('Venta guardada. Caja y stock al dia.'), findsOneWidget);
      expect(store.movements.first.title, 'Venta');
      expect(store.productById('p-alpha')?.stockUnits, 4);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
