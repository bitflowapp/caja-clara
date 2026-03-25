import 'package:flutter/widgets.dart';

import '../services/barcode_lookup_service.dart';

class BarcodeLookupScope extends InheritedWidget {
  const BarcodeLookupScope({
    super.key,
    required this.service,
    required super.child,
  });

  final BarcodeLookupService service;

  static BarcodeLookupService of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<BarcodeLookupScope>();
    return scope?.service ?? const DisabledBarcodeLookupService();
  }

  @override
  bool updateShouldNotify(covariant BarcodeLookupScope oldWidget) {
    return oldWidget.service != service;
  }
}
