import 'package:flutter/material.dart';

class ScfColors {
  static const surface = Color(0xFF12161C);
  static const surfaceRaised = Color(0xFF1A2029);
  static const surfaceCard = Color(0xFF212935);
  static const outline = Color(0xFF313C4B);

  static const accent = Color(0xFFFF7A2F);
  static const accentDim = Color(0xFFB3521B);

  static const success = Color(0xFF3DBE64);
  static const danger = Color(0xFFE04B4B);
  static const info = Color(0xFF3E8EC4);
  static const warning = Color(0xFFE8B93C);

  static const textPrimary = Color(0xFFEDF1F5);
  static const textSecondary = Color(0xFF9AA7B5);

  static const courtLine = Color(0xFFD8DEE6);
  static const courtFill = Color(0xFF2A3543);
  static const courtZoneFill = Color(0xFF334152);

  static const goalFrame = Color(0xFFE8EDF2);
  static const goalNet = Color(0x33E8EDF2);
}

class AppTheme {
  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    final scheme = ColorScheme.fromSeed(
      seedColor: ScfColors.accent,
      brightness: Brightness.dark,
      surface: ScfColors.surface,
    );
    return base.copyWith(
      colorScheme: scheme.copyWith(
        primary: ScfColors.accent,
        secondary: ScfColors.info,
        surface: ScfColors.surface,
        error: ScfColors.danger,
      ),
      scaffoldBackgroundColor: ScfColors.surface,
      appBarTheme: const AppBarTheme(
        backgroundColor: ScfColors.surfaceRaised,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: ScfColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: ScfColors.textPrimary),
      ),
      cardTheme: const CardThemeData(
        color: ScfColors.surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: ScfColors.outline),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(color: ScfColors.outline, thickness: 1),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: ScfColors.surfaceRaised,
        contentTextStyle: TextStyle(color: ScfColors.textPrimary),
        behavior: SnackBarBehavior.floating,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ScfColors.surfaceRaised,
        labelStyle: const TextStyle(color: ScfColors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: ScfColors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: ScfColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: ScfColors.accent, width: 1.4),
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
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: ScfColors.outline),
          ),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: ScfColors.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: ScfColors.textPrimary,
        unselectedLabelColor: ScfColors.textSecondary,
        indicatorColor: ScfColors.accent,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: ScfColors.surfaceCard,
        side: const BorderSide(color: ScfColors.outline),
        labelStyle: const TextStyle(color: ScfColors.textPrimary),
      ),
      splashColor: ScfColors.accent.withValues(alpha: 0.12),
      highlightColor: ScfColors.accent.withValues(alpha: 0.08),
    );
  }
}
