import 'package:flutter/material.dart';

import 'app/b_plus_commerce_app.dart';
import 'app/services/barcode_lookup_service.dart';
import 'app/services/commerce_store.dart';
import 'app/services/license_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await CommerceStore.loadOrSeed();
  final licenseService = await LicenseService.loadOrCreate();
  store.attachLicenseService(licenseService);
  final barcodeLookupService = BarcodeLookupService.fromEnvironment();
  runApp(
    BPlusCommerceApp(
      store: store,
      barcodeLookupService: barcodeLookupService,
      licenseService: licenseService,
    ),
  );
}
