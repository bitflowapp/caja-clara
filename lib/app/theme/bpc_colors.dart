import 'package:flutter/material.dart';

/// Tokens de diseño de Caja Clara.
///
/// Estética cálida, premium y sobria: fondo arena suave, superficies blancas,
/// verde profundo como acento principal y un dorado/ámbar muy sutil.
class BpcColors {
  // --- Tinta / texto ---------------------------------------------------
  static const Color ink = Color(0xFF15201B); // gris casi negro, cálido
  static const Color mutedInk = Color(0xFF55615A); // texto secundario
  static const Color subtleInk = Color(0xFF828C84); // hints / texto terciario

  // --- Fondos y superficies -------------------------------------------
  static const Color paper = Color(0xFFF5F2EA); // fondo general (arena suave)
  static const Color paperShade = Color(0xFFEDE8DB);
  static const Color surface = Color(0xFFFFFFFF); // tarjetas (blanco cálido)
  static const Color surfaceStrong = Color(0xFFF7F3EA); // superficie tranquila
  static const Color surfaceTint = Color(0xFFFBF9F3);
  static const Color line = Color(0xFFE8E2D5); // hairline suave
  static const Color lineStrong = Color(0xFFD9D1C0);

  // --- Verdes de marca -------------------------------------------------
  static const Color greenDark = Color(0xFF14463B); // acento principal
  static const Color greenDeep = Color(0xFF0E3429); // paneles oscuros
  static const Color greenSoft = Color(0xFF3B6258);

  // --- Arena / dorado --------------------------------------------------
  static const Color sand = Color(0xFFD8C49B);
  static const Color sandSoft = Color(0xFFEADFC6);
  static const Color sandMuted = Color(0xFFB89B6A);
  static const Color gold = Color(0xFFB98B2E); // acento secundario sutil

  // --- Semántica -------------------------------------------------------
  static const Color income = Color(0xFF1C7A5E); // éxito / entra plata
  static const Color incomeSoft = Color(0xFFE4F1EB);
  static const Color expense = Color(0xFFB04A3A); // sale plata / error suave
  static const Color expenseSoft = Color(0xFFF5E3DE);
  static const Color warning = Color(0xFFC0851F); // ámbar de aviso
  static const Color warningSoft = Color(0xFFF9EFD6);

  // --- Elevación -------------------------------------------------------
  static const Color shadow = Color(0x12101A14);
  static const Color shadowStrong = Color(0x1F101A14);
}
