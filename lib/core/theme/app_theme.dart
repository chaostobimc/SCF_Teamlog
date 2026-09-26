import 'package:flutter/material.dart';

class ScfColors {
  // Flächen: tiefes Blauschwarz mit klarer Staffelung.
  static const background = Color(0xFF0A0F17);
  static const surface = Color(0xFF101823);
  static const surfaceRaised = Color(0xFF16202D);
  static const surfaceCard = Color(0xFF1A2534);
  static const outline = Color(0xFF26344A);
  static const outlineSoft = Color(0xFF1D2938);

  // Markenfarben.
  static const accent = Color(0xFFFF7A2F);
  static const accentSoft = Color(0x33FF7A2F);
  static const accentDim = Color(0xFFC25A1E);
  static const cyan = Color(0xFF38BDF8);
  static const cyanSoft = Color(0x3338BDF8);

  // Semantik.
  static const success = Color(0xFF34D399);
  static const successSoft = Color(0x3334D399);
  static const danger = Color(0xFFF43F5E);
  static const dangerSoft = Color(0x33F43F5E);
  static const warning = Color(0xFFFBBF24);
  static const warningSoft = Color(0x33FBBF24);
  static const violet = Color(0xFFA78BFA);

  // Text.
  static const textPrimary = Color(0xFFEAF1F8);
  static const textSecondary = Color(0xFF8B9CB0);
  static const textFaint = Color(0xFF5C6E82);

  // Spielfeld.
  static const courtLine = Color(0xFFE8EEF5);
  static const courtFill = Color(0xFF16283C);
  static const courtZoneFill = Color(0xFF1E3450);

  // Tor.
  static const goalFrame = Color(0xFFDCE4EC);
  static const goalNet = Color(0x22000000);
  static const goalCell = Color(0xFF121B27);
}

class AppTheme {
  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    final scheme = ColorScheme.fromSeed(
      seedColor: ScfColors.accent,
      brightness: Brightness.dark,
      surface: ScfColors.surface,
    ).copyWith(
      primary: ScfColors.accent,
      secondary: ScfColors.cyan,
      surface: ScfColors.surface,
      error: ScfColors.danger,
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: ScfColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: ScfColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: ScfColors.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
        iconTheme: IconThemeData(color: ScfColors.textPrimary),
      ),
      cardTheme: const CardThemeData(
        color: ScfColors.surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          side: BorderSide(color: ScfColors.outline),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme:
          const DividerThemeData(color: ScfColors.outlineSoft, thickness: 1),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: ScfColors.surfaceRaised,
        contentTextStyle: TextStyle(color: ScfColors.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ScfColors.surfaceRaised,
        labelStyle: const TextStyle(color: ScfColors.textSecondary),
        hintStyle: const TextStyle(color: ScfColors.textFaint),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ScfColors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ScfColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ScfColors.accent, width: 1.5),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: const MenuStyle(
          backgroundColor: WidgetStatePropertyAll(ScfColors.surfaceRaised),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: ScfColors.surfaceRaised,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: ScfColors.outline),
          ),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: ScfColors.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        titleTextStyle: TextStyle(
          color: ScfColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: TextStyle(color: ScfColors.textSecondary),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: ScfColors.textPrimary,
        unselectedLabelColor: ScfColors.textSecondary,
        indicatorColor: ScfColors.accent,
        labelStyle: TextStyle(fontWeight: FontWeight.w700),
        dividerColor: ScfColors.outlineSoft,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: ScfColors.surfaceCard,
        side: const BorderSide(color: ScfColors.outline),
        labelStyle: const TextStyle(color: ScfColors.textPrimary),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ScfColors.accent,
          foregroundColor: Colors.black,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ScfColors.textPrimary,
          side: const BorderSide(color: ScfColors.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ScfColors.textSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: ScfColors.textSecondary,
        textColor: ScfColors.textPrimary,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: ScfColors.accent,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      splashColor: ScfColors.accent.withValues(alpha: 0.10),
      highlightColor: ScfColors.accent.withValues(alpha: 0.06),
    );
  }
}

/// Kleine Helfer fuer konsistente Label-Styles.
class ScfText {
  static const sectionLabel = TextStyle(
    color: ScfColors.textSecondary,
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.3,
  );

  static const caption = TextStyle(
    color: ScfColors.textSecondary,
    fontSize: 12,
  );

  static const numberBig = TextStyle(
    color: ScfColors.textPrimary,
    fontSize: 34,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.5,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
