import 'package:flutter/material.dart';

/// Tokens de diseño de Caja Clara.
///
/// Estética "Graphite comfort": superficie grafito para jornadas largas,
/// acentos azules contenidos, bordes sutiles y texto claro.
///
/// Nota de compatibilidad: las constantes históricas `green*` se conservan
/// como alias para no romper imports; ahora apuntan a los azules de marca.
class BpcColors {
  // --- Tinta / texto ---------------------------------------------------
  static const Color ink = Color(0xFFF3F4F6); // texto primario
  static const Color mutedInk = Color(0xFFB7BDC7); // texto secundario
  static const Color subtleInk = Color(0xFF8F96A3); // texto terciario / hints

  // --- Fondos y superficies -------------------------------------------
  static const Color paper = Color(0xFF202124); // fondo general
  static const Color paperShade = Color(0xFF26282C); // superficie secundaria
  static const Color surface = Color(0xFF2B2D31); // tarjetas
  static const Color surfaceStrong = Color(0xFF26282C); // superficie secundaria
  static const Color surfaceTint = Color(0xFF1F2023); // sidebar / shell
  static const Color line = Color(0xFF3A3D42); // hairline / borde
  static const Color lineStrong = Color(0xFF4B5058); // borde fuerte

  // --- Azul de marca ---------------------------------------------------
  static const Color accent = Color(0xFF6B94E8); // azul Caja Clara (acento)
  static const Color accentStrong = Color(0xFF5A7FD0); // azul CTA contenido
  static const Color accentDeep = Color(0xFF3D5EAA); // azul profundo (paneles)
  static const Color accentSoft = Color(0xFF26324A); // azul suave (activos)

  // Alias legacy: el código existente usa `green*`; ahora son azules.
  static const Color greenDark = accent; // acento principal
  static const Color greenDeep = accentDeep; // paneles oscuros
  static const Color greenSoft = accentStrong;

  // --- Tonos secundarios ----------------------------------------------
  static const Color sand = accentSoft;
  static const Color sandSoft = accentSoft;
  static const Color sandMuted = Color(0xFF8091B5);
  static const Color gold = Color(0xFFD4A85A); // ámbar de acento puntual

  // --- Semántica -------------------------------------------------------
  static const Color income = Color(0xFF68A982); // éxito / entra plata
  static const Color incomeSoft = Color(0xFF25352E);
  static const Color expense = Color(0xFFD27676); // sale plata / error
  static const Color expenseSoft = Color(0xFF3A292C);
  static const Color warning = Color(0xFFD4A85A); // ámbar de aviso
  static const Color warningSoft = Color(0xFF3A3224);

  // --- Elevación -------------------------------------------------------
  static const Color shadow = Color(0x33000000); // sombra suave
  static const Color shadowStrong = Color(0x52000000);
}
