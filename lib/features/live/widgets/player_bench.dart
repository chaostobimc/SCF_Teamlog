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
            const SizedBox(width: 8),
            for (final player in goalkeepers)
              _JerseyChip(
                player: player,
                team: team,
                selected: player.id == selectedPlayerId,
                onTap: () => onPlayerTap(player.id),
              ),
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
            runSpacing: 8,
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
          const SizedBox(height: 14),
          const _SectionLabel('Torhüter'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: ScfColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 62,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [team.primaryColor, team.primaryColor.withValues(alpha: 0.8)],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected
                      ? ScfColors.accent
                      : (isKeeper ? ScfColors.info : ScfColors.outline),
                  width: selected ? 3 : 1.5,
                ),
                boxShadow: selected
                    ? [BoxShadow(color: ScfColors.accent.withValues(alpha: 0.4), blurRadius: 8)]
                    : null,
              ),
              alignment: Alignment.center,
              child: Text(
                '${player.number}',
                style: TextStyle(
                  color: _contrastColor(team.primaryColor),
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              player.shortName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: ScfColors.textSecondary, fontSize: 10.5),
            ),
          ],
        ),
      ),
    );
  }

  Color _contrastColor(Color background) {
    final luminance = background.computeLuminance();
    return luminance > 0.45 ? ScfColors.surface : ScfColors.textPrimary;
  }
}
