import 'package:flutter/material.dart';

import 'app/b_plus_commerce_app.dart';
import 'app/services/commerce_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await CommerceStore.loadOrSeed();
  runApp(BPlusCommerceApp(store: store));
}

