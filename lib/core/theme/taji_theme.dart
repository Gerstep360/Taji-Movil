import 'package:flutter/material.dart';

class TajiColors {
  static const primary = Color(0xFF0F6FFF);
  static const primaryStrong = Color(0xFF075AD7);
  static const primarySoft = Color(0xFFEAF4FF);
  static const ink = Color(0xFF10233C);
  static const muted = Color(0xFF6F7F93);
  static const border = Color(0xFFDCE4ED);
  static const canvas = Color(0xFFF4F7FB);
  static const success = Color(0xFF16855E);
  static const danger = Color(0xFFB43C49);
}

ThemeData buildTajiTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: TajiColors.primary,
    brightness: Brightness.light,
    primary: TajiColors.primary,
    surface: Colors.white,
    error: TajiColors.danger,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: TajiColors.canvas,
    fontFamily: 'Segoe UI',
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        color: TajiColors.ink,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.4,
      ),
      headlineSmall: TextStyle(
        color: TajiColors.ink,
        fontWeight: FontWeight.w800,
        letterSpacing: -.7,
      ),
      titleMedium: TextStyle(
        color: TajiColors.ink,
        fontWeight: FontWeight.w700,
      ),
      bodyMedium: TextStyle(color: TajiColors.muted, height: 1.5),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: TajiColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: TajiColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: TajiColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: TajiColors.danger),
      ),
      labelStyle: const TextStyle(color: TajiColors.muted),
      hintStyle: const TextStyle(color: Color(0xFFA4AFBD)),
    ),
  );
}
