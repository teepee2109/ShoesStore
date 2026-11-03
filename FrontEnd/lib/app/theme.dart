import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  const ink = Color(0xFF171717);
  const accent = Color(0xFFD7F542);

  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: ink,
      primary: ink,
      secondary: accent,
      surface: const Color(0xFFFAFAF8),
    ),
    scaffoldBackgroundColor: const Color(0xFFFAFAF8),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFFAFAF8),
      foregroundColor: ink,
      elevation: 0,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE8E8E4)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: ink, width: 1.5),
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
  );
}
