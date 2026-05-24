import 'package:flutter/material.dart';

/// Tokens de diseño de Caja Clara.
///
/// Estética "Luna Systems light premium": fondo gris muy claro y frío,
/// superficies blancas, azul de marca como acento, esquinas redondeadas
/// y sombras suaves. Look SaaS/B2B moderno, claro y legible.
///
/// Nota de compatibilidad: las constantes históricas `green*` se conservan
/// como alias para no romper imports; ahora apuntan a los azules de marca.
class BpcColors {
  // --- Tinta / texto ---------------------------------------------------
  static const Color ink = Color(0xFF0E1726); // texto primario
  static const Color mutedInk = Color(0xFF475467); // texto secundario
  static const Color subtleInk = Color(0xFF8A94A6); // texto terciario / hints

  // --- Fondos y superficies -------------------------------------------
  static const Color paper = Color(0xFFF6F8FB); // fondo general
  static const Color paperShade = Color(0xFFEEF2F7); // superficie secundaria
  static const Color surface = Color(0xFFFFFFFF); // tarjetas
  static const Color surfaceStrong = Color(0xFFEEF2F7); // superficie secundaria
  static const Color surfaceTint = Color(0xFFFAFBFD); // superficie muy sutil
  static const Color line = Color(0xFFE3E8EF); // hairline / borde
  static const Color lineStrong = Color(0xFFCBD5E1); // borde fuerte

  // --- Azul de marca ---------------------------------------------------
  static const Color accent = Color(0xFF3B82F6); // azul Caja Clara (acento)
  static const Color accentStrong = Color(0xFF2563EB); // azul Luna (hover/seed)
  static const Color accentDeep = Color(0xFF1D4ED8); // azul profundo (paneles)
  static const Color accentSoft = Color(0xFFEAF1FE); // azul suave (activos)

  // Alias legacy: el código existente usa `green*`; ahora son azules.
  static const Color greenDark = accent; // acento principal
  static const Color greenDeep = accentDeep; // paneles oscuros
  static const Color greenSoft = accentStrong;

  // --- Tonos secundarios ----------------------------------------------
  static const Color sand = accentSoft;
  static const Color sandSoft = accentSoft;
  static const Color sandMuted = Color(0xFF93B4F0);
  static const Color gold = Color(0xFFF59E0B); // ámbar de acento puntual

  // --- Semántica -------------------------------------------------------
  static const Color income = Color(0xFF16A34A); // éxito / entra plata
  static const Color incomeSoft = Color(0xFFE7F6EC);
  static const Color expense = Color(0xFFDC2626); // sale plata / error
  static const Color expenseSoft = Color(0xFFFBE9E9);
  static const Color warning = Color(0xFFF59E0B); // ámbar de aviso
  static const Color warningSoft = Color(0xFFFEF3E0);

  // --- Elevación -------------------------------------------------------
  static const Color shadow = Color(0x0F0E1726); // sombra suave
  static const Color shadowStrong = Color(0x1A0E1726);
}
