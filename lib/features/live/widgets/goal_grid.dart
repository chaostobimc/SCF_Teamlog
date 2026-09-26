import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/match_event.dart';
import '../../../logic/stats_calculator.dart';

/// Tor-Raster mit den sechs Tresorzonen plus Daneben-Zonen.
class GoalGrid extends StatelessWidget {
  const GoalGrid({
    super.key,
    required this.onZoneTap,
    this.selectedZone,
    this.zones,
    this.showTallies = false,
    this.enabled = true,
  });

  final ValueChanged<GoalZone> onZoneTap;
  final GoalZone? selectedZone;
  final Map<GoalZone, ZoneTally>? zones;
  final bool showTallies;
  final bool enabled;

  static const double cellWidth = 64;
  static const double cellHeight = 44;
  static const double frameHeight = 2 * (cellHeight + 3) + 5 + 10;

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
          children: [
            _OuterColumn(
              zone: GoalZone.linksDaneben,
              selected: selectedZone,
              zones: zones,
              showTallies: showTallies,
              enabled: enabled,
              onTap: onZoneTap,
            ),
            const SizedBox(width: 3),
            _GoalFrame(
              selected: selectedZone,
              zones: zones,
              showTallies: showTallies,
              enabled: enabled,
              onTap: onZoneTap,
            ),
            const SizedBox(width: 3),
            _OuterColumn(
              zone: GoalZone.rechtsDaneben,
              selected: selectedZone,
              zones: zones,
              showTallies: showTallies,
              enabled: enabled,
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
    required this.onTap,
  });

  final GoalZone? selected;
  final Map<GoalZone, ZoneTally>? zones;
  final bool showTallies;
  final bool enabled;
  final ValueChanged<GoalZone> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: ScfColors.goalFrame,
        borderRadius: BorderRadius.circular(4),
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
                    onTap: onTap,
                  ),
              ],
            ),
            if (row == 0) const SizedBox(height: 5),
          ],
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.zone,
    required this.selected,
    required this.zones,
    required this.showTallies,
    required this.enabled,
    required this.onTap,
  });

  final GoalZone zone;
  final GoalZone? selected;
  final Map<GoalZone, ZoneTally>? zones;
  final bool showTallies;
  final bool enabled;
  final ValueChanged<GoalZone> onTap;

  @override
  Widget build(BuildContext context) {
    final tally = zones?[zone];
    final isSelected = selected == zone;
    Color fill = ScfColors.surfaceCard;
    if (tally != null && showTallies && tally.total > 0) {
      fill = tally.goals > 0
          ? ScfColors.success.withValues(alpha: 0.30)
          : ScfColors.danger.withValues(alpha: 0.30);
    }
    if (isSelected) fill = ScfColors.accent;

    return GestureDetector(
      onTap: enabled ? () => onTap(zone) : null,
      child: Container(
        width: GoalGrid.cellWidth,
        height: GoalGrid.cellHeight,
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          color: fill,
          border: Border.all(
            color: isSelected ? ScfColors.textPrimary : ScfColors.goalNet,
            width: isSelected ? 2 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: tally != null && showTallies && tally.total > 0
            ? Text(
                '${tally.goals}/${tally.total}',
                style: const TextStyle(
                  color: ScfColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              )
            : null,
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
    required this.onTap,
  });

  final GoalZone zone;
  final GoalZone? selected;
  final Map<GoalZone, ZoneTally>? zones;
  final bool showTallies;
  final bool enabled;
  final ValueChanged<GoalZone> onTap;

  @override
  Widget build(BuildContext context) {
    final tally = zones?[zone];
    final isSelected = selected == zone;
    Color fill = ScfColors.surfaceRaised;
    if (isSelected) fill = ScfColors.accentDim;

    return GestureDetector(
      onTap: enabled ? () => onTap(zone) : null,
      child: Container(
        width: 26,
        height: GoalGrid.frameHeight - 10,
        margin: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: fill,
          border: Border.all(
            color: isSelected ? ScfColors.textPrimary : ScfColors.outline,
          ),
          borderRadius: BorderRadius.circular(3),
        ),
        alignment: Alignment.center,
        child: tally != null && tally.total > 0
            ? RotatedBox(
                quarterTurns: -1,
                child: Text(
                  '${tally.goals}/${tally.total}',
                  style: const TextStyle(
                    color: ScfColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            : null,
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
      padding: const EdgeInsets.only(bottom: 3, left: 29, right: 29),
      child: GestureDetector(
        onTap: enabled ? () => onTap(GoalZone.drueber) : null,
        child: Container(
          height: 18,
          decoration: BoxDecoration(
            color: isSelected ? ScfColors.accentDim : ScfColors.surfaceRaised,
            border: Border.all(
              color: isSelected ? ScfColors.textPrimary : ScfColors.outline,
            ),
            borderRadius: BorderRadius.circular(3),
          ),
          alignment: Alignment.center,
          child: Text(
            'Über die Latte',
            style: TextStyle(
              color: isSelected ? ScfColors.textPrimary : ScfColors.textSecondary,
              fontSize: 10,
            ),
          ),
        ),
      ),
    );
  }
}
