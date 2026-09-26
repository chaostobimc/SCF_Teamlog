import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/match_event.dart';
import '../../../logic/stats_calculator.dart';

/// Farbgebung der Zonen: Schuetze (gruen = Tore) oder Torwart (gruen = Paraden).
enum GoalGridMode { shooter, goalkeeper }

/// Tor-Raster mit den sechs Tresorzonen plus Daneben-Zonen.
class GoalGrid extends StatelessWidget {
  const GoalGrid({
    super.key,
    required this.onZoneTap,
    this.selectedZone,
    this.zones,
    this.showTallies = false,
    this.enabled = true,
    this.mode = GoalGridMode.shooter,
  });

  final ValueChanged<GoalZone> onZoneTap;
  final GoalZone? selectedZone;
  final Map<GoalZone, ZoneTally>? zones;
  final bool showTallies;
  final bool enabled;
  final GoalGridMode mode;

  static const double cellWidth = 68;
  static const double cellHeight = 46;
  static const double frameHeight = 2 * (cellHeight + 3) + 8 + 12;

  static const List<GoalZone> _inner = [
    GoalZone.obenLinks,
    GoalZone.obenMitte,
    GoalZone.obenRechts,
    GoalZone.untenLinks,
    GoalZone.untenMitte,
    GoalZone.untenRechts,
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _DrueberStrip(
          selected: selectedZone,
          enabled: enabled,
          onTap: onZoneTap,
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _OuterColumn(
              zone: GoalZone.linksDaneben,
              selected: selectedZone,
              zones: zones,
              showTallies: showTallies,
              enabled: enabled,
              mode: mode,
              onTap: onZoneTap,
            ),
            const SizedBox(width: 4),
            _GoalFrame(
              selected: selectedZone,
              zones: zones,
              showTallies: showTallies,
              enabled: enabled,
              mode: mode,
              onTap: onZoneTap,
            ),
            const SizedBox(width: 4),
            _OuterColumn(
              zone: GoalZone.rechtsDaneben,
              selected: selectedZone,
              zones: zones,
              showTallies: showTallies,
              enabled: enabled,
              mode: mode,
              onTap: onZoneTap,
            ),
          ],
        ),
      ],
    );
  }
}

class _GoalFrame extends StatelessWidget {
  const _GoalFrame({
    required this.selected,
    required this.zones,
    required this.showTallies,
    required this.enabled,
    required this.mode,
    required this.onTap,
  });

  final GoalZone? selected;
  final Map<GoalZone, ZoneTally>? zones;
  final bool showTallies;
  final bool enabled;
  final GoalGridMode mode;
  final ValueChanged<GoalZone> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: ScfColors.goalFrame,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var row = 0; row < 2; row++) ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var col = 0; col < 3; col++)
                  _Cell(
                    zone: GoalGrid._inner[row * 3 + col],
                    selected: selected,
                    zones: zones,
                    showTallies: showTallies,
                    enabled: enabled,
                    mode: mode,
                    onTap: onTap,
                  ),
              ],
            ),
            if (row == 0) const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

String _cellText(ZoneTally tally, GoalGridMode mode) {
  final primary = mode == GoalGridMode.shooter ? tally.goals : tally.saved;
  return '$primary/${tally.total}';
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.zone,
    required this.selected,
    required this.zones,
    required this.showTallies,
    required this.enabled,
    required this.mode,
    required this.onTap,
  });

  final GoalZone zone;
  final GoalZone? selected;
  final Map<GoalZone, ZoneTally>? zones;
  final bool showTallies;
  final bool enabled;
  final GoalGridMode mode;
  final ValueChanged<GoalZone> onTap;

  @override
  Widget build(BuildContext context) {
    final tally = zones?[zone];
    final isSelected = selected == zone;
    final hasData = tally != null && showTallies && tally.total > 0;

    Color fill = ScfColors.goalCell;
    if (hasData) {
      final positive =
          mode == GoalGridMode.shooter ? tally.goals > 0 : tally.saved > 0;
      fill = positive
          ? ScfColors.success.withValues(alpha: 0.28)
          : ScfColors.danger.withValues(alpha: 0.28);
    }
    if (isSelected) fill = ScfColors.accent;

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTap: enabled ? () => onTap(zone) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: GoalGrid.cellWidth,
          height: GoalGrid.cellHeight,
          margin: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            color: fill,
            border: Border.all(
              color: isSelected
                  ? ScfColors.textPrimary
                  : (hasData ? ScfColors.outline : const Color(0xFF243244)),
              width: isSelected ? 2.2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: ScfColors.accent.withValues(alpha: 0.45),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: hasData
              ? Text(
                  _cellText(tally!, mode),
                  style: const TextStyle(
                    color: ScfColors.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

class _OuterColumn extends StatelessWidget {
  const _OuterColumn({
    required this.zone,
    required this.selected,
    required this.zones,
    required this.showTallies,
    required this.enabled,
    required this.mode,
    required this.onTap,
  });

  final GoalZone zone;
  final GoalZone? selected;
  final Map<GoalZone, ZoneTally>? zones;
  final bool showTallies;
  final bool enabled;
  final GoalGridMode mode;
  final ValueChanged<GoalZone> onTap;

  @override
  Widget build(BuildContext context) {
    final tally = zones?[zone];
    final isSelected = selected == zone;
    Color fill = ScfColors.surfaceRaised;
    if (isSelected) fill = ScfColors.accentDim;

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTap: enabled ? () => onTap(zone) : null,
        child: Container(
          width: 30,
          height: GoalGrid.frameHeight,
          decoration: BoxDecoration(
            color: fill,
            border: Border.all(
              color: isSelected ? ScfColors.textPrimary : ScfColors.outline,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: RotatedBox(
            quarterTurns: -1,
            child: Text(
              tally != null && tally.total > 0
                  ? _cellText(tally, mode)
                  : zone.label,
              style: TextStyle(
                color: isSelected ? ScfColors.textPrimary : ScfColors.textFaint,
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DrueberStrip extends StatelessWidget {
  const _DrueberStrip({
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final GoalZone? selected;
  final bool enabled;
  final ValueChanged<GoalZone> onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == GoalZone.drueber;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, left: 34, right: 34),
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        child: GestureDetector(
          onTap: enabled ? () => onTap(GoalZone.drueber) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            height: 20,
            decoration: BoxDecoration(
              color: isSelected ? ScfColors.accentDim : ScfColors.surfaceRaised,
              border: Border.all(
                color: isSelected ? ScfColors.textPrimary : ScfColors.outline,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Text(
              'ÜBER DIE LATTE',
              style: TextStyle(
                color:
                    isSelected ? ScfColors.textPrimary : ScfColors.textFaint,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
