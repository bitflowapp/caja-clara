import 'package:flutter/widgets.dart';

import '../services/license_service.dart';

class LicenseScope extends InheritedNotifier<LicenseService> {
  const LicenseScope({
    super.key,
    required LicenseService service,
    required super.child,
  }) : super(notifier: service);

  static LicenseService of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LicenseScope>();
    return scope?.notifier ?? LicenseService.fallback();
  }
}
