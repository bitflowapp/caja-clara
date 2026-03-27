import 'dart:ui';

import 'package:b_plus_commerce/app/b_plus_commerce_app.dart';
import 'package:b_plus_commerce/app/services/barcode_lookup_service.dart';
import 'package:b_plus_commerce/app/services/commerce_store.dart';
import 'package:b_plus_commerce/app/services/license_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'expired Windows trial blocks new sale and opens activation dialog',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final now = DateTime(2026, 3, 26, 10, 0);
      final store = CommerceStore.seededForTest();
      final licenseService = LicenseService.forTest(
        clock: () => now,
        installationId: 'CCW-TEST-LIC1',
        trialStartedAt: now.subtract(const Duration(days: 31)),
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

      expect(find.text('Activacion necesaria'), findsOneWidget);

      await tester.ensureVisible(find.text('Nueva venta'));
      await tester.tap(find.text('Nueva venta'));
      await tester.pumpAndSettle();

      expect(find.text('Activar Caja Clara'), findsWidgets);
      expect(find.text('ID de esta PC'), findsOneWidget);
      expect(find.text('Registrar venta'), findsNothing);
    },
  );
}
