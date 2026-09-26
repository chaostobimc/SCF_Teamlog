import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/player.dart';
import '../../../data/models/team.dart';

/// Spielerleiste: Trikot-Chips zur Schnellauswahl des aktiven Spielers.
class PlayerBench extends StatelessWidget {
  const PlayerBench({
    super.key,
    required this.team,
    required this.selectedPlayerId,
    required this.onPlayerTap,
    this.axis = Axis.vertical,
  });

  final Team team;
  final String? selectedPlayerId;
  final ValueChanged<String> onPlayerTap;
  final Axis axis;

  @override
  Widget build(BuildContext context) {
    final fieldPlayers = team.fieldPlayers
      ..sort((a, b) => a.number.compareTo(b.number));
    final goalkeepers = team.goalkeepers
      ..sort((a, b) => a.number.compareTo(b.number));

    if (axis == Axis.horizontal) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final player in fieldPlayers)
              _JerseyChip(
                player: player,
                team: team,
                selected: player.id == selectedPlayerId,
                onTap: () => onPlayerTap(player.id),
              ),
            if (goalkeepers.isNotEmpty) ...[
              Container(
                width: 1,
                height: 44,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: ScfColors.outline,
              ),
              for (final player in goalkeepers)
                _JerseyChip(
                  player: player,
                  team: team,
                  selected: player.id == selectedPlayerId,
                  onTap: () => onPlayerTap(player.id),
                ),
            ],
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionLabel('Feldspieler'),
          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: [
              for (final player in fieldPlayers)
                _JerseyChip(
                  player: player,
                  team: team,
                  selected: player.id == selectedPlayerId,
                  onTap: () => onPlayerTap(player.id),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const _SectionLabel('Torhüter'),
          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: [
              for (final player in goalkeepers)
                _JerseyChip(
                  player: player,
                  team: team,
                  selected: player.id == selectedPlayerId,
                  onTap: () => onPlayerTap(player.id),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text.toUpperCase(), style: ScfText.sectionLabel),
    );
  }
}

class _JerseyChip extends StatelessWidget {
  const _JerseyChip({
    required this.player,
    required this.team,
    required this.selected,
    required this.onTap,
  });

  final Player player;
  final Team team;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isKeeper = player.position == PlayerPosition.torwart;
    final borderColor = selected
        ? ScfColors.accent
        : (isKeeper ? ScfColors.cyan.withValues(alpha: 0.7) : ScfColors.outline);

    return Tooltip(
      message: player.fullName,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 130),
            width: 60,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        team.primaryColor,
                        Color.lerp(team.primaryColor, Colors.black, 0.22)!,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: borderColor,
                      width: selected ? 2.5 : 1.4,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: ScfColors.accent.withValues(alpha: 0.45),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${player.number}',
                    style: TextStyle(
                      color: _contrastColor(team.primaryColor),
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  player.shortName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected
                        ? ScfColors.textPrimary
                        : ScfColors.textFaint,
                    fontSize: 10,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _contrastColor(Color background) {
    final luminance = background.computeLuminance();
    return luminance > 0.5 ? ScfColors.background : ScfColors.textPrimary;
  }
}
