import 'package:flutter/widgets.dart';

import '../services/commerce_store.dart';

class CommerceScope extends InheritedNotifier<CommerceStore> {
  const CommerceScope({
    super.key,
    required CommerceStore store,
    required super.child,
  }) : super(notifier: store);

  static CommerceStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CommerceScope>();
    assert(scope != null, 'CommerceScope not found in widget tree');
    return scope!.notifier!;
  }
}
