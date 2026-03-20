import 'package:flutter/material.dart';

import 'bpc_colors.dart';

class BpcTheme {
  static ThemeData light() {
    final cs = ColorScheme.fromSeed(
      seedColor: BpcColors.greenDark,
      brightness: Brightness.light,
      surface: BpcColors.surface,
      error: BpcColors.expense,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: cs.copyWith(
        primary: BpcColors.greenDark,
        secondary: BpcColors.sand,
        tertiary: BpcColors.sandSoft,
        outline: BpcColors.line,
        outlineVariant: BpcColors.lineStrong,
        surfaceContainerLow: BpcColors.surfaceStrong,
        surfaceContainerHighest: BpcColors.paperShade,
        onSurface: BpcColors.ink,
      ),
      scaffoldBackgroundColor: BpcColors.paper,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: BpcColors.ink,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: BpcColors.paper,
        selectedIconTheme: const IconThemeData(
          color: BpcColors.greenDark,
          size: 23,
        ),
        unselectedIconTheme: const IconThemeData(
          color: BpcColors.mutedInk,
          size: 22,
        ),
        selectedLabelTextStyle: const TextStyle(
          color: BpcColors.ink,
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
        unselectedLabelTextStyle: const TextStyle(
          color: BpcColors.mutedInk,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        indicatorColor: BpcColors.sandSoft,
        minWidth: 108,
        minExtendedWidth: 220,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: BpcColors.surface,
        indicatorColor: BpcColors.sandSoft,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? BpcColors.greenDark : BpcColors.mutedInk,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? BpcColors.ink : BpcColors.mutedInk,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
            fontSize: 12,
          );
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: BpcColors.greenDark,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.1,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: BpcColors.greenDark,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.1,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: BpcColors.ink,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        behavior: SnackBarBehavior.floating,
      ),
      dividerColor: BpcColors.line,
      cardTheme: CardThemeData(
        color: BpcColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: BpcColors.line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: BpcColors.surface,
        hintStyle: const TextStyle(
          color: BpcColors.subtleInk,
          fontWeight: FontWeight.w600,
        ),
        labelStyle: const TextStyle(
          color: BpcColors.mutedInk,
          fontWeight: FontWeight.w700,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: BpcColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: BpcColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: BpcColors.greenDark.withValues(alpha: 0.72),
            width: 1.8,
          ),
        ),
      ),
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: BpcColors.ink,
        displayColor: BpcColors.ink,
      ).copyWith(
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w900,
          letterSpacing: -0.8,
          color: BpcColors.ink,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w900,
          letterSpacing: -0.45,
          color: BpcColors.ink,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
          color: BpcColors.ink,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(
          color: BpcColors.mutedInk,
          height: 1.28,
        ),
        bodySmall: base.textTheme.bodySmall?.copyWith(
          color: BpcColors.subtleInk,
        ),
        labelLarge: base.textTheme.labelLarge?.copyWith(
          color: BpcColors.mutedInk,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}
