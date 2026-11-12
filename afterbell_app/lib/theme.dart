import 'package:flutter/material.dart';

class AB {
  static const Color dusk = Color(0xFF0E1633);
  static const Color orange = Color(0xFFFF8A1F);
  static const Color sun = Color(0xFFFFB21A);
  static const Color teal = Color(0xFF0FB5A6);
  static const Color coral = Color(0xFFFF6B4A);
  static const Color sky = Color(0xFF4C7DFF);
  static const Color bg = Color(0xFFF6F7FC);
  static const Color line = Color(0xFFE1E5F0);
  static const Color muted = Color(0xFF56617C);
  static const Color red = Color(0xFFE5362F);

  /// Soft card colors, the same six tones as the website.
  static const List<Color> tones = <Color>[
    Color(0xFFFFE6A8),
    Color(0xFFBFF0E8),
    Color(0xFFFFD3C7),
    Color(0xFFD3DCFF),
    Color(0xFFDAF1B5),
    Color(0xFFF5D1EA),
  ];

  static ThemeData theme() {
    final ColorScheme scheme = ColorScheme.fromSeed(seedColor: orange, brightness: Brightness.light).copyWith(
      primary: orange,
      onPrimary: const Color(0xFF1B1100),
      secondary: teal,
      surface: Colors.white,
      onSurface: dusk,
      error: red,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        foregroundColor: dusk,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(color: dusk, fontSize: 20, fontWeight: FontWeight.w800),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: orange,
          foregroundColor: const Color(0xFF1B1100),
          minimumSize: const Size(0, 50),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: dusk,
          minimumSize: const Size(0, 50),
          shape: const StadiumBorder(),
          side: const BorderSide(color: dusk, width: 1.5),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: line)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: line)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: sky, width: 2)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: sun.withAlpha(90),
        height: 68,
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}

const TextStyle h1 = TextStyle(fontSize: 26, height: 1.12, fontWeight: FontWeight.w800, color: AB.dusk, letterSpacing: -0.5);
const TextStyle h2 = TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AB.dusk);
const TextStyle mutedText = TextStyle(color: AB.muted, fontSize: 14, height: 1.4);
