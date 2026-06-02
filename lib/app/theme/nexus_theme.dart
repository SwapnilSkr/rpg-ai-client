import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Everlore Design System — Premium (neumorphism + skeuomorphism)
///
/// Color model: a genre-neutral **shell** (warm-obsidian ground + champagne-
/// brass chrome + the forged/neumorphic *form*) carries the brand, while the
/// **content** layer (play / world / voice) tints to the active world's genre
/// via [sceneAccent] (a world-driven accent). The material language is hue-agnostic,
/// so the premium feel stays constant while the color breathes with the story.
///
/// Typography:
///  • Cinzel      — engraved, ceremonial display & titles (the fantasy stamp)
///  • General Sans — neutral premium UI grotesk (labels, buttons, body)
///  • EB Garamond — serif narrative prose (reads like an illuminated tome)
class EverloreTheme {
  // The bundled UI grotesk (see pubspec fonts:). Use [ui] to build styles.
  static const String uiFamily = 'GeneralSans';

  // ──────────────── Palette ────────────────
  // Ground — warm obsidian (forged-iron charcoal with a faint amber undertone).
  static const Color void0 = Color(0xFF0A0807); // deepest bg
  static const Color void1 = Color(0xFF0F0C0A); // scaffold bg
  static const Color void2 = Color(0xFF16120E); // card bg
  static const Color void3 = Color(0xFF1E1813); // card bg raised
  static const Color void4 = Color(0xFF2A2219); // input bg / hover

  // Champagne-brass — the brand metal (forged-metal ramp for real bevels).
  static const Color goldDeep = Color(0xFF6E5A2E); // engraved/recessed shadow
  static const Color goldDim = Color(0xFF9A8350); // dim brass for borders
  static const Color gold = Color(0xFFD8B878); // champagne-brass — primary
  static const Color goldGlow = Color(0xFFECD49A); // bright brass for glow
  static const Color goldHot = Color(0xFFFBEFCB); // specular hotspot

  // Aether — the single cool "energy" spark (live moments only). The legacy
  // violet/cyan accent tokens redirect here so old usages read aether, not
  // purple; per-screen content accents come from [sceneAccent].
  static const Color aether = Color(0xFF3FC9D6); // aqua-teal spark
  static const Color aetherDim = Color(0xFF1E8A95);
  static const Color aetherBright = Color(0xFF5FDDE8);

  // Legacy accent aliases (kept so existing references compile; retuned to the
  // new system). Migrate call sites to aether/dynamicAccent during reskin.
  static const Color violet = aether;
  static const Color violetDim = aetherDim;
  static const Color violetBright = aetherBright;
  static const Color cyan = aetherDim;
  static const Color cyanBright = aether;
  static const Color rose = Color(0xFFEC4899); // intimate scenes

  static const Color parchment = Color(0xFFE8DCC8); // primary text
  static const Color ash = Color(0xFF9C948A); // secondary text (warm-neutral)
  static const Color ember = Color(0xFFD97706); // warning / mid
  static const Color verdant = Color(0xFF059669); // success / high health
  static const Color crimson = Color(0xFFDC2626); // danger / low health

  static const Color white10 = Color(0x1AFFFFFF);
  static const Color white20 = Color(0x33FFFFFF);
  static const Color white40 = Color(0x66FFFFFF);

  // ──────────────── Typography ────────────────
  static TextStyle get displayTitle => GoogleFonts.cinzel(
        color: gold,
        fontSize: 30,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
        height: 1.15,
      );

  static TextStyle get screenTitle => GoogleFonts.cinzel(
        color: parchment,
        fontSize: 19,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      );

  static TextStyle get sectionHeader => ui(
        color: gold,
        size: 11,
        weight: FontWeight.w700,
        spacing: 2.5,
      );

  static TextStyle get cardTitle => GoogleFonts.cinzel(
        color: parchment,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
      );

  static TextStyle get body => ui(
        color: parchment,
        size: 15,
        height: 1.6,
      );

  static TextStyle get bodyDim => ui(
        color: ash,
        size: 13,
        height: 1.5,
      );

  static TextStyle get caption => ui(
        color: ash,
        size: 11,
        spacing: 0.5,
      );

  /// Serif narrative prose used for AI story text.
  static TextStyle get aiText => GoogleFonts.ebGaramond(
        color: const Color(0xFFEADFC9),
        fontSize: 18,
        height: 1.72,
        letterSpacing: 0.15,
      );

  /// General Sans helper for arbitrary UI text (keeps font usage centralized).
  static TextStyle ui({
    double size = 14,
    Color color = parchment,
    FontWeight weight = FontWeight.w400,
    double spacing = 0,
    double? height,
    FontStyle? fontStyle,
  }) =>
      TextStyle(
        fontFamily: uiFamily,
        color: color,
        fontSize: size,
        fontWeight: weight,
        letterSpacing: spacing,
        height: height,
        fontStyle: fontStyle,
      );

  /// Cinzel helper for ceremonial labels.
  static TextStyle serifDisplay({
    double size = 18,
    Color color = parchment,
    FontWeight weight = FontWeight.w600,
    double spacing = 0.5,
    double? height,
  }) =>
      GoogleFonts.cinzel(
        color: color,
        fontSize: size,
        fontWeight: weight,
        letterSpacing: spacing,
        height: height,
      );

  // ──────────────── Scene accents ────────────────
  /// Accent colour for a given scene tag — drives the immersive backdrop,
  /// scene badges, and any scene-aware chrome across the app.
  static Color sceneAccent(String? tag) {
    return switch (tag) {
      'combat' => crimson,
      'intimate' => rose,
      'exploration' => verdant,
      'existential' => cyanBright,
      'cosmic' => violetBright,
      'dialogue' => gold,
      'mundane' => ash,
      _ => gold,
    };
  }

  // ──────────────── Decorations ────────────────
  static List<BoxShadow> glow(Color color, {double blur = 20, double alpha = 0.25}) =>
      [BoxShadow(color: color.withValues(alpha: alpha), blurRadius: blur, spreadRadius: 0)];

  static BoxDecoration get cardDecoration => BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: goldDim.withValues(alpha: 0.3), width: 1),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1C160F), Color(0xFF100C09)],
        ),
      );

  static BoxDecoration get cardDecorationGlow => BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: gold.withValues(alpha: 0.5), width: 1),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF231B12), Color(0xFF130E0A)],
        ),
        boxShadow: [
          BoxShadow(color: gold.withValues(alpha: 0.12), blurRadius: 24, spreadRadius: 0),
        ],
      );

  static BoxDecoration get inputDecoration => BoxDecoration(
        color: void4,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: goldDim.withValues(alpha: 0.3), width: 1),
      );

  // ──────────────── ThemeData ────────────────
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
      textTheme: ThemeData.dark().textTheme.apply(fontFamily: uiFamily).copyWith(
        displayLarge: displayTitle,
        titleLarge: cardTitle,
        bodyLarge: body,
        bodyMedium: bodyDim,
        bodySmall: caption,
      ),
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
      appBarTheme: AppBarTheme(
        backgroundColor: void0,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: screenTitle,
        iconTheme: const IconThemeData(color: ash),
      ),
      cardTheme: CardThemeData(
        color: void2,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: void0,
          textStyle: ui(weight: FontWeight.w700, spacing: 0.8, size: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: gold,
          side: const BorderSide(color: goldDim, width: 1),
          textStyle: ui(weight: FontWeight.w600, spacing: 0.5, size: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: void4,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: goldDim.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: goldDim.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: gold, width: 1.5),
        ),
        hintStyle: ui(color: const Color(0xFF6B5E4D), size: 14),
        labelStyle: ui(color: ash),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
        overlayColor: Color(0x22D8B878),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: void4,
        labelStyle: ui(color: ash, size: 11),
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
