import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'services/commerce_store.dart';
import 'theme/bpc_theme.dart';
import 'widgets/commerce_scope.dart';
import 'widgets/responsive_shell.dart';

class BPlusCommerceApp extends StatelessWidget {
  const BPlusCommerceApp({super.key, required this.store});

  final CommerceStore store;

  @override
  Widget build(BuildContext context) {
    return CommerceScope(
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
                colors: [
                  Color(0xFFF3ECDD),
                  Color(0xFFEEE6D8),
                ],
              ),
            ),
            child: Stack(
              children: [
                child ?? const SizedBox.shrink(),
                if (kDebugMode)
                  const Positioned(
                    right: 10,
                    bottom: 10,
                    child: _DebugBadge(),
                  ),
              ],
            ),
          );
        },
        home: const ResponsiveShell(),
      ),
    );
  }
}

class _DebugBadge extends StatelessWidget {
  const _DebugBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          'DEBUG',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
