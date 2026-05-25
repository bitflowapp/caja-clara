import 'package:b_plus_commerce/app/services/license_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tool/generate_activation_code.dart' as generator;

void main() {
  test('developer activation generator matches LicenseService', () {
    const installationId = 'CCW-N2T3-TCZK-TW3C';

    expect(
      generator.generateActivationCode(installationId),
      LicenseService.generateActivationCode(installationId),
    );
  });
}
