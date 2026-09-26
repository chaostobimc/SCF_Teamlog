import 'package:flutter/material.dart';

/// Farbwelt: dunkles "Sports Telemetry" – fast schwarzblaue Flächen,
/// glühendes Orange als Marke, Cyan für Torwart/Gegner.
class ScfColors {
  static const background = Color(0xFF060A10);
  static const surface = Color(0xFF0B121C);
  static const surfaceRaised = Color(0xFF121B28);
  static const surfaceCard = Color(0xFF101925);
  static const outline = Color(0xFF1E2B3D);
  static const outlineSoft = Color(0xFF16202E);

  static const accent = Color(0xFFFF6B35);
  static const accentHot = Color(0xFFFF8A5C);
  static const accentSoft = Color(0x26FF6B35);
  static const accentDim = Color(0xFFB34A21);

  static const cyan = Color(0xFF22D3EE);
  static const cyanSoft = Color(0x2622D3EE);

  static const success = Color(0xFF22C55E);
  static const successSoft = Color(0x2622C55E);
  static const danger = Color(0xFFEF4444);
  static const dangerSoft = Color(0x26EF4444);
  static const warning = Color(0xFFF59E0B);
  static const warningSoft = Color(0x26F59E0B);
  static const violet = Color(0xFF8B5CF6);

  static const textPrimary = Color(0xFFF8FAFC);
  static const textSecondary = Color(0xFF94A3B8);
  static const textFaint = Color(0xFF64748B);

  static const courtLine = Color(0xFFE2E8F0);
  static const courtFill = Color(0xFF12202F);
  static const courtZoneFill = Color(0xFF1A2C40);

  static const goalFrame = Color(0xFFE2E8F0);
  static const goalCell = Color(0xFF0E1722);
  static const goalNet = Color(0x26000000);
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
        backgroundColor: ScfColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: ScfColors.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: ScfColors.textPrimary),
      ),
      cardTheme: const CardThemeData(
        color: ScfColors.surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
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
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
        titleTextStyle: TextStyle(
          color: ScfColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle: TextStyle(color: ScfColors.textSecondary),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: ScfColors.textPrimary,
        unselectedLabelColor: ScfColors.textSecondary,
        indicatorColor: ScfColors.accent,
        labelStyle: TextStyle(fontWeight: FontWeight.w800),
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
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
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
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: ScfColors.accentSoft,
          selectedForegroundColor: ScfColors.accent,
          foregroundColor: ScfColors.textSecondary,
          side: const BorderSide(color: ScfColors.outline),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      splashColor: ScfColors.accent.withValues(alpha: 0.10),
      highlightColor: ScfColors.accent.withValues(alpha: 0.06),
    );
  }
}

/// Wiederverwendbare Text-Styles.
class ScfText {
  static const sectionLabel = TextStyle(
    color: ScfColors.textSecondary,
    fontSize: 10.5,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.4,
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

/// Aufgeblasene Icon-Kachel mit Label (fuer Aktionsflaechen).
class ScfTile extends StatelessWidget {
  const ScfTile({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.color,
    this.enabled = true,
    this.dense = false,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? color;
  final bool enabled;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tone = color ?? ScfColors.textSecondary;
    return Material(
      color: enabled
          ? tone.withValues(alpha: 0.12)
          : ScfColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: enabled
                  ? tone.withValues(alpha: 0.45)
                  : ScfColors.outlineSoft,
            ),
          ),
          padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 12),
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon,
                    size: dense ? 15 : 18,
                    color: enabled ? tone : ScfColors.textFaint),
                SizedBox(width: dense ? 6 : 9),
              ],
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: enabled
                        ? ScfColors.textPrimary
                        : ScfColors.textFaint,
                    fontWeight: FontWeight.w700,
                    fontSize: dense ? 11.5 : 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
