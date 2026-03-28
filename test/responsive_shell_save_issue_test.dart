import 'dart:ui';

import 'package:b_plus_commerce/app/b_plus_commerce_app.dart';
import 'package:b_plus_commerce/app/models/product.dart';
import 'package:b_plus_commerce/app/services/barcode_lookup_service.dart';
import 'package:b_plus_commerce/app/services/commerce_persistence.dart';
import 'package:b_plus_commerce/app/services/commerce_store.dart';
import 'package:b_plus_commerce/app/services/license_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'desktop recoverable save issue becomes summary-only after the top notice settles',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final store = CommerceStore.withPersistenceForTest(
        _AlwaysFailPersistence(),
        seedDemoData: true,
      );
      final licenseService = LicenseService.forTest(
        installationId: 'CCW-TEST-SAVE',
        enforceRestrictions: false,
      );
      store.attachLicenseService(licenseService);

      await tester.pumpWidget(
        BPlusCommerceApp(
          store: store,
          barcodeLookupService: const DisabledBarcodeLookupService(),
          licenseService: licenseService,
        ),
      );
      await tester.pumpAndSettle();

      try {
        await store.addProduct(
          const Product(
            id: 'save-issue-preview',
            name: 'Producto prueba',
            stockUnits: 2,
            minStockUnits: 0,
            costPesos: 1000,
            pricePesos: 1500,
            category: 'Otros',
          ),
        );
      } catch (_) {}

      await tester.pump();

      expect(find.text('Guardado pendiente'), findsOneWidget);
      expect(find.text('Pendiente de guardado'), findsOneWidget);

      await tester.pump(const Duration(seconds: 9));
      await tester.pump();

      expect(find.text('Guardado pendiente'), findsNothing);
      expect(find.text('Pendiente de guardado'), findsOneWidget);
    },
  );
}

class _AlwaysFailPersistence extends CommercePersistence {
  @override
  Future<Map<String, dynamic>?> load() async => null;

  @override
  Future<void> save(Map<String, dynamic> json) async {
    throw Exception('disk full');
  }
}
