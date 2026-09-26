import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/player.dart';

/// Vertikale Trikotnummern-Leiste am linken Bildschirmrand.
class PlayerRail extends StatelessWidget {
  const PlayerRail({
    super.key,
    required this.players,
    required this.selectedPlayerId,
    required this.onPlayerTap,
    this.width = 64,
  });

  final List<Player> players;
  final String? selectedPlayerId;
  final ValueChanged<String> onPlayerTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final fieldPlayers = players
        .where((p) => p.position == PlayerPosition.feldspieler)
        .toList()
      ..sort((a, b) => a.number.compareTo(b.number));
    final goalkeepers = players
        .where((p) => p.position == PlayerPosition.torwart)
        .toList()
      ..sort((a, b) => a.number.compareTo(b.number));

    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _RailScroll(
              children: [
                for (final player in fieldPlayers)
                  _NumberChip(
                    player: player,
                    selected: player.id == selectedPlayerId,
                    onTap: () => onPlayerTap(player.id),
                  ),
              ],
            ),
          ),
          if (goalkeepers.isNotEmpty) ...[
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(vertical: 4),
              color: ScfColors.outline,
            ),
            _RailScroll(
              shrinkWrap: true,
              children: [
                for (final player in goalkeepers)
                  _NumberChip(
                    player: player,
                    selected: player.id == selectedPlayerId,
                    onTap: () => onPlayerTap(player.id),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RailScroll extends StatelessWidget {
  const _RailScroll({required this.children, this.shrinkWrap = false});

  final List<Widget> children;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemHeight = 62.0;
        final fits = !shrinkWrap || children.length * itemHeight < 220;
        if (fits && children.length * itemHeight <= constraints.maxHeight) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: children,
          );
        }
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        );
      },
    );
  }
}

class _NumberChip extends StatelessWidget {
  const _NumberChip({
    required this.player,
    required this.selected,
    required this.onTap,
  });

  final Player player;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isKeeper = player.position == PlayerPosition.torwart;
    final base = isKeeper ? ScfColors.cyan : ScfColors.accent;

    return Tooltip(
      message: player.fullName,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            margin: const EdgeInsets.symmetric(vertical: 3),
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: selected
                    ? [base, Color.lerp(base, Colors.black, 0.25)!]
                    : [
                        ScfColors.surfaceRaised,
                        ScfColors.surfaceRaised,
                      ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? base : ScfColors.outline,
                width: selected ? 2 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: base.withValues(alpha: 0.4),
                        blurRadius: 10,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${player.number}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: selected ? Colors.black : ScfColors.textPrimary,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                SizedBox(
                  height: 12,
                  child: Text(
                    player.shortName,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: 8,
                      color: selected
                          ? Colors.black.withValues(alpha: 0.8)
                          : ScfColors.textFaint,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
