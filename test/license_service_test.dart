import 'package:b_plus_commerce/app/services/license_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LicenseService', () {
    test('keeps trial active for 30 days and then expires', () {
      final now = DateTime(2026, 3, 26, 10, 0);
      final activeService = LicenseService.forTest(
        clock: () => now,
        installationId: 'CCW-TEST-0001',
        trialStartedAt: now.subtract(const Duration(days: 12)),
      );
      final expiredService = LicenseService.forTest(
        clock: () => now,
        installationId: 'CCW-TEST-0002',
        trialStartedAt: now.subtract(const Duration(days: 31)),
      );

      expect(activeService.status, LicenseStatus.trialActive);
      expect(activeService.trialDaysRemaining, 18);
      expect(expiredService.status, LicenseStatus.trialExpired);
      expect(expiredService.canUse(LockedFeature.sales), isFalse);
    });

    test('activates with a matching code and rejects a foreign one', () async {
      final now = DateTime(2026, 3, 26, 10, 0);
      final service = LicenseService.forTest(
        clock: () => now,
        installationId: 'CCW-TEST-ABCD',
        trialStartedAt: now.subtract(const Duration(days: 31)),
      );

      final validCode = LicenseService.generateActivationCode(
        service.installationId,
      );

      await service.activate(validCode);

      expect(service.status, LicenseStatus.active);
      expect(service.canUse(LockedFeature.sales), isTrue);

      final otherService = LicenseService.forTest(
        clock: () => now,
        installationId: 'CCW-TEST-EFGH',
        trialStartedAt: now.subtract(const Duration(days: 31)),
      );

      await expectLater(
        otherService.activate(validCode),
        throwsA(isA<StateError>()),
      );
    });

    test('does not enforce restrictions outside the Windows product flow', () {
      final now = DateTime(2026, 3, 26, 10, 0);
      final service = LicenseService.forTest(
        clock: () => now,
        installationId: 'CCW-TEST-WEB1',
        trialStartedAt: now.subtract(const Duration(days: 120)),
        enforceRestrictions: false,
      );

      expect(service.shouldShowLicenseUi, isFalse);
      expect(service.status, LicenseStatus.active);
      expect(service.canUse(LockedFeature.sales), isTrue);
    });
  });
}
