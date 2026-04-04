import 'package:flutter/material.dart';

/// Everlore Design System — Dark Fantasy RPG
class EverloreTheme {
  // ──────────────── Palette ────────────────
  static const Color void0 = Color(0xFF07070E); // deepest bg
  static const Color void1 = Color(0xFF0D0D1C); // scaffold bg
  static const Color void2 = Color(0xFF13132A); // card bg
  static const Color void3 = Color(0xFF1A1A38); // card bg raised
  static const Color void4 = Color(0xFF252548); // input bg / hover

  static const Color gold = Color(0xFFD4A843);   // arcane gold — primary
  static const Color goldDim = Color(0xFF8A6820); // dim gold for borders
  static const Color goldGlow = Color(0xFFF0C86A); // bright gold for glow

  static const Color violet = Color(0xFF7C3AED);  // mystic violet
  static const Color violetDim = Color(0xFF4C1D95);
  static const Color violetBright = Color(0xFFA855F7);

  static const Color cyan = Color(0xFF0891B2);   // ethereal cyan (AI text)
  static const Color cyanBright = Color(0xFF22D3EE);

  static const Color parchment = Color(0xFFE8DCC8); // primary text
  static const Color ash = Color(0xFF9CA3AF);        // secondary text
  static const Color ember = Color(0xFFD97706);      // warning / mid
  static const Color verdant = Color(0xFF059669);    // success / high health
  static const Color crimson = Color(0xFFDC2626);    // danger / low health

  static const Color white10 = Color(0x1AFFFFFF);
  static const Color white20 = Color(0x33FFFFFF);
  static const Color white40 = Color(0x66FFFFFF);

  // ──────────────── Text Styles ────────────────
  static const TextStyle displayTitle = TextStyle(
    color: gold,
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: 3.0,
    height: 1.1,
  );

  static const TextStyle screenTitle = TextStyle(
    color: parchment,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.5,
  );

  static const TextStyle sectionHeader = TextStyle(
    color: gold,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 2.0,
  );

  static const TextStyle cardTitle = TextStyle(
    color: parchment,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );

  static const TextStyle body = TextStyle(
    color: parchment,
    fontSize: 15,
    height: 1.6,
  );

  static const TextStyle bodyDim = TextStyle(
    color: ash,
    fontSize: 13,
    height: 1.5,
  );

  static const TextStyle caption = TextStyle(
    color: ash,
    fontSize: 11,
    letterSpacing: 0.5,
  );

  static const TextStyle aiText = TextStyle(
    color: Color(0xFFCBEAF5),
    fontSize: 15,
    height: 1.7,
    letterSpacing: 0.1,
  );

  // ──────────────── Decorations ────────────────
  static BoxDecoration get cardDecoration => BoxDecoration(
        color: void2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: goldDim.withValues(alpha: 0.35), width: 1),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF16163A), Color(0xFF0F0F28)],
        ),
      );

  static BoxDecoration get cardDecorationGlow => BoxDecoration(
        color: void2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: gold.withValues(alpha: 0.5), width: 1),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E1A40), Color(0xFF120F2A)],
        ),
        boxShadow: [
          BoxShadow(
            color: gold.withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: 0,
          ),
        ],
      );

  static BoxDecoration get inputDecoration => BoxDecoration(
        color: void4,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: goldDim.withValues(alpha: 0.3), width: 1),
      );

  // ──────────────── ThemeData ────────────────
  /// Horizontal slide in/out for push and pop (in-app bar + system back).
  /// Avoids Material’s zoom-style transition on Android, which reads as a harsh “pop.”
  static const PageTransitionsTheme _pageTransitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
      TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
      TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
    },
  );

  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      pageTransitionsTheme: _pageTransitions,
      scaffoldBackgroundColor: void1,
      primaryColor: gold,
      colorScheme: const ColorScheme.dark(
        primary: gold,
        secondary: violet,
        tertiary: cyan,
        surface: void2,
        error: crimson,
        onPrimary: void1,
        onSecondary: Colors.white,
        onSurface: parchment,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: void0,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: screenTitle,
        iconTheme: IconThemeData(color: ash),
      ),
      cardTheme: CardThemeData(
        color: void2,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: void1,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            fontSize: 14,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: gold,
          side: const BorderSide(color: goldDim, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: void4,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: goldDim.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: goldDim.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: gold, width: 1.5),
        ),
        hintStyle: const TextStyle(color: Color(0xFF5A5A80), fontSize: 14),
        labelStyle: const TextStyle(color: ash),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      textTheme: const TextTheme(
        displayLarge: displayTitle,
        titleLarge: cardTitle,
        bodyLarge: body,
        bodyMedium: bodyDim,
        bodySmall: caption,
      ),
      dividerColor: white10,
      dialogTheme: DialogThemeData(
        backgroundColor: void2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: goldDim.withValues(alpha: 0.4)),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: gold,
        thumbColor: gold,
        inactiveTrackColor: void4,
        overlayColor: Color(0x22D4A843),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: void4,
        labelStyle: const TextStyle(color: ash, fontSize: 11),
        side: BorderSide(color: goldDim.withValues(alpha: 0.3)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      ),
    );
  }
}

/// Keep the old name as alias for compatibility
class NexusTheme {
  static ThemeData get dark => EverloreTheme.dark;
}
