// Paleta del blog BabyWolf ("Dark Gaming / Cyberpunk Minimal"), copiada de
// DOCUMENTACION_Y_GUIA_DE_ESTILOS.md para que el teléfono se vea igual que la web.

import 'package:flutter/material.dart';

const kFondo = Color(0xFF1A1A2E); // Space Void
const kSuperficie = Color(0xFF16213E); // Elevación (cards / nav)
const kNeon = Color(0xFFE94560); // Action Red: bordes, glows, botones
const kNeonGlow = Color(0x4DE94560);

/// Derivación más clara del mismo tono, sólo para TEXTO. El #E94560 sobre las
/// tarjetas se queda en 4.15:1 y no llega al 4.5:1 de WCAG AA, que sí aplica
/// al texto pequeño como el chip de categoría (11 px).
const kNeonTexto = Color(0xFFF2748A);
const kTexto = Color(0xE6FFFFFF); // Evita el blanco puro en bloques largos
const kTenue = Color(0x99FFFFFF);
const kVerde = Color(0xFF4ADE80);

/// Icono de consola retro por tema, igual que en el wearable.
const kConsolas = <String, IconData>{
  'retro': Icons.videogame_asset,
  'gaming': Icons.sports_esports,
  'tech': Icons.memory,
  'opinion': Icons.tv,
};

IconData consolaDe(String categoria) =>
    kConsolas[categoria] ?? Icons.article_outlined;

ThemeData babywolfTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: kFondo,
    colorScheme: base.colorScheme.copyWith(
      primary: kNeon,
      surface: kSuperficie,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: kFondo,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
  );
}
