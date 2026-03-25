import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'services/barcode_lookup_service.dart';
import 'services/commerce_store.dart';
import 'widgets/barcode_lookup_scope.dart';
import 'theme/bpc_theme.dart';
import 'widgets/commerce_scope.dart';
import 'widgets/responsive_shell.dart';

class BPlusCommerceApp extends StatelessWidget {
  const BPlusCommerceApp({
    super.key,
    required this.store,
    required this.barcodeLookupService,
  });

  final CommerceStore store;
  final BarcodeLookupService barcodeLookupService;

  @override
  Widget build(BuildContext context) {
    return BarcodeLookupScope(
      service: barcodeLookupService,
      child: CommerceScope(
        store: store,
        child: MaterialApp(
          title: 'Caja Clara',
          debugShowCheckedModeBanner: false,
          theme: BpcTheme.light(),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('es', 'AR'),
            Locale('es'),
            Locale('en'),
          ],
          builder: (context, child) {
            return DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFF3ECDD), Color(0xFFEEE6D8)],
                ),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const ResponsiveShell(),
        ),
      ),
    );
  }
}
