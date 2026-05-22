import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Light SquadUp palette aligned with `squadUp-layout` CSS tokens (approximate hex).
class SquadColors {
  SquadColors._();

  static const text = Color(0xFF24183A);
  static const muted = Color(0xFF6B6280);
  static const card = Color(0xFFFFFFFF);
  static const border = Color(0xFFE8E4EF);
  static const inputFill = Color(0xFFF2EFF8);
  static const mutedBg = Color(0xFFF2EFF8);

  /// Coral / pink primary
  static const primary = Color(0xFFE85D75);
  static const primaryGlow = Color(0xFFF07890);

  /// Purple secondary
  static const secondary = Color(0xFF8B4DD9);

  static const danger = Color(0xFFE04D5C);

  static const hoops = Color(0xFFD4892E);
  static const hoopsSoft = Color(0xFFF5E8D6);
  static const swim = Color(0xFF2E8FBF);
  static const swimSoft = Color(0xFFE3F0FA);
  static const cafe = Color(0xFF6B4AA8);
  static const cafeSoft = Color(0xFFEDE8F7);
  static const study = Color(0xFF2A9B73);
  static const studySoft = Color(0xFFE4F5EE);
  static const gaming = Color(0xFFE04D4D);
  static const gamingSoft = Color(0xFFFCE8E8);
  static const success = Color(0xFF2A9B73);
  static const successSoft = Color(0xFFE4F5EE);

  /// Top → bottom background gradient.
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFFDF2F7),
      Color(0xFFF5F0FA),
    ],
  );

  /// Primary → secondary (CTAs).
  static const LinearGradient ctaGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEB6B84), Color(0xFF9B4DD9)],
  );

  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
      blurRadius: 20,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> primaryGlowShadow = [
    BoxShadow(
      color: primary.withValues(alpha: 0.38),
      blurRadius: 28,
      offset: const Offset(0, 10),
    ),
  ];

  /// Legacy names mapped to new tokens (existing screens).
  static const bg = Color(0xFFF5F0FA);
  static const surface = card;
  static const surface2 = inputFill;
  static const accent = primary;
  static const accent2 = secondary;
}

ThemeData buildSquadTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: Colors.transparent,
    colorScheme: ColorScheme.light(
      primary: SquadColors.primary,
      onPrimary: Colors.white,
      secondary: SquadColors.secondary,
      onSecondary: Colors.white,
      surface: SquadColors.card,
      onSurface: SquadColors.text,
      error: SquadColors.danger,
      onError: Colors.white,
      outline: SquadColors.border,
    ),
  );

  final jakarta = GoogleFonts.plusJakartaSansTextTheme(base.textTheme);

  return base.copyWith(
    textTheme: jakarta.apply(
      bodyColor: SquadColors.text,
      displayColor: SquadColors.text,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      foregroundColor: SquadColors.text,
    ),
    cardTheme: CardThemeData(
      color: SquadColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      shadowColor: Colors.black26,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: SquadColors.inputFill,
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: SquadColors.primary.withValues(alpha: 0.45),
          width: 2,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: TextStyle(
        color: SquadColors.muted.withValues(alpha: 0.75),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: SquadColors.primary,
      ),
    ),
  );
}

TextStyle squadDisplay(BuildContext context, double size) {
  return GoogleFonts.plusJakartaSans(
    fontSize: size,
    fontWeight: FontWeight.w800,
    color: SquadColors.text,
    height: 1.15,
  );
}
