import 'package:b_plus_commerce/app/models/product.dart';
import 'package:b_plus_commerce/app/screens/barcode_scan_screen.dart';
import 'package:b_plus_commerce/app/screens/sale_screen.dart';
import 'package:b_plus_commerce/app/services/barcode_lookup_service.dart';
import 'package:b_plus_commerce/app/services/commerce_store.dart';
import 'package:b_plus_commerce/app/widgets/barcode_lookup_scope.dart';
import 'package:b_plus_commerce/app/widgets/commerce_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeBarcodeLookupService extends BarcodeLookupService {
  _FakeBarcodeLookupService(this._handler);

  final Future<BarcodeLookupResult> Function(String normalizedBarcode) _handler;

  @override
  String get providerLabel => 'Lookup de prueba';

  @override
  bool get isEnabled => true;

  @override
  Future<BarcodeLookupResult> lookup(String normalizedBarcode) {
    return _handler(normalizedBarcode);
  }
}

void main() {
  Future<void> pumpBarcodeScreen(
    WidgetTester tester,
    CommerceStore store, {
    BarcodeLookupService? lookupService,
    Size size = const Size(1100, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      BarcodeLookupScope(
        service: lookupService ?? const DisabledBarcodeLookupService(),
        child: CommerceScope(
          store: store,
          child: const MaterialApp(home: BarcodeScanScreen()),
        ),
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
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Buscar producto'),
      ),
    );
    await tester.pumpAndSettle();
  }

  TextFormField fieldByLabel(String label, WidgetTester tester) {
    return tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, label),
    );
  }

  testWidgets(
    'manual fallback resolves an existing local barcode without duplicates',
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
      await enterManualBarcode(tester, 'abc-123');

      expect(find.text('Ya existe en catalogo'), findsOneWidget);
      expect(find.text('Cable USB-C'), findsOneWidget);
      expect(find.text('Cod. ABC123'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'desktop scanner field resolves a local product with keyboard-wedge flow',
    (tester) async {
      final store = CommerceStore.emptyForTest();
      await store.addProduct(
        const Product(
          id: 'p-desktop',
          name: 'Mouse gamer',
          stockUnits: 3,
          minStockUnits: 1,
          costPesos: 12000,
          pricePesos: 18900,
          barcode: 'WIN-123',
        ),
      );

      await pumpBarcodeScreen(tester, store);

      await tester.enterText(
        find.widgetWithText(TextField, 'Scanner USB o codigo manual'),
        'win 123',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(find.text('Ya existe en catalogo'), findsOneWidget);
      expect(find.text('Mouse gamer'), findsOneWidget);
      expect(find.text('Cod. WIN123'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'external barcode match prefills assisted product creation',
    (tester) async {
      final store = CommerceStore.emptyForTest();
      final lookupService = _FakeBarcodeLookupService(
        (barcode) async => BarcodeLookupResult.found(
          const BarcodeLookupMatch(
            barcode: '3274080005003',
            name: 'Eau De Source',
            brand: 'Cristaline',
            suggestedCategory: 'Bebidas',
            sourceLabel: 'Open Food Facts',
          ),
        ),
      );

      await pumpBarcodeScreen(tester, store, lookupService: lookupService);
      await enterManualBarcode(tester, '3274080005003');

      expect(find.text('Datos encontrados afuera'), findsOneWidget);
      expect(find.text('Cristaline Eau De Source'), findsOneWidget);
      expect(find.text('Fuente: Open Food Facts'), findsOneWidget);

      await tester.tap(find.text('Crear con datos sugeridos'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));

      expect(
        fieldByLabel('Nombre', tester).controller?.text,
        'Cristaline Eau De Source',
      );
      expect(
        fieldByLabel('Categoria', tester).controller?.text,
        'Bebidas',
      );
      expect(
        fieldByLabel('Codigo de barras (opcional)', tester).controller?.text,
        '3274080005003',
      );
      expect(find.text('Datos sugeridos por Open Food Facts'), findsOneWidget);
      expect(find.text('Marca: Cristaline'), findsOneWidget);

      await tester.ensureVisible(find.text('Guardar'));
      await tester.tap(find.text('Guardar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        store.productByBarcode('3274080005003')?.name,
        'Cristaline Eau De Source',
      );
      expect(store.productByBarcode('3274080005003')?.category, 'Bebidas');
      expect(find.text('Ya existe en catalogo'), findsOneWidget);
      expect(
        find.text(
          'Producto guardado. Ese codigo ya queda listo para futuras busquedas.',
        ),
        findsOneWidget,
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'barcode without external match falls back to assisted manual creation',
    (tester) async {
      final store = CommerceStore.emptyForTest();
      final lookupService = _FakeBarcodeLookupService(
        (barcode) async => const BarcodeLookupResult.notFound(
          message:
              'No encontramos ese codigo en el catalogo externo. Puedes cargarlo manualmente.',
        ),
      );

      await pumpBarcodeScreen(tester, store, lookupService: lookupService);
      await enterManualBarcode(tester, 'ABC999');

      expect(find.text('No esta en catalogo'), findsOneWidget);
      expect(
        find.text(
          'No encontramos ese codigo en el catalogo externo. Puedes cargarlo manualmente.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Crear producto'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));

      expect(fieldByLabel('Nombre', tester).controller?.text, isEmpty);
      expect(
        fieldByLabel('Codigo de barras (opcional)', tester).controller?.text,
        'ABC999',
      );
      expect(find.text('Codigo listo'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'external lookup failure keeps the flow honest and manual',
    (tester) async {
      final store = CommerceStore.emptyForTest();
      final lookupService = _FakeBarcodeLookupService(
        (barcode) async => const BarcodeLookupResult.failed(
          message:
              'No pudimos consultar el catalogo externo ahora. Puedes seguir con alta manual.',
        ),
      );

      await pumpBarcodeScreen(tester, store, lookupService: lookupService);
      await enterManualBarcode(tester, 'XYZ404');

      expect(
        find.text('No pudimos completar la busqueda externa'),
        findsOneWidget,
      );
      expect(
        find.text(
          'No pudimos consultar el catalogo externo ahora. Puedes seguir con alta manual.',
        ),
        findsOneWidget,
      );
      expect(find.text('Crear producto'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'scanner sale flow records the sale and updates stock',
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

      final saveSaleButton = find
          .ancestor(
            of: find.descendant(
              of: find.byType(SaleScreen),
              matching: find.text('Registrar venta'),
            ),
            matching: find.bySubtype<ButtonStyleButton>(),
          )
          .first;
      await tester.ensureVisible(saveSaleButton);
      tester.widget<ButtonStyleButton>(saveSaleButton).onPressed?.call();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(store.movements.first.title, 'Venta');
      expect(store.productById('p-alpha')?.stockUnits, 4);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
