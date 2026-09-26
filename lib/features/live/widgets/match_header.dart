import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_formatters.dart';
import '../../../data/models/match.dart';
import '../../../data/models/match_event.dart';
import '../../../logic/match_state.dart';

/// Kompakte Zeile: Phase | Uhr (editierbar) | Teams | Score | Steuerung.
class MatchHeader extends StatelessWidget {
  const MatchHeader({
    super.key,
    required this.state,
    required this.onEditTime,
    required this.onPhaseAction,
    required this.onFinish,
  });

  final MatchState state;
  final VoidCallback onEditTime;

  /// Uebergang zur 2. Halbzeit.
  final VoidCallback onPhaseAction;

  /// Spiel beenden.
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final match = state.match;
    final team = state.team;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: ScfColors.surface,
        border: Border(bottom: BorderSide(color: ScfColors.outlineSoft)),
      ),
      child: Row(
        children: [
          _PhaseChips(match: match, onSecondHalf: onPhaseAction),
          const SizedBox(width: 12),
          InkWell(
            onTap: onEditTime,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: ScfColors.surfaceRaised,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ScfColors.outline),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppFormatters.clock(match.phaseElapsedSec),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: ScfColors.textPrimary,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.edit, size: 14, color: ScfColors.textFaint),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${team?.name ?? 'SC Freising'} – ${match.opponentName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
                Text(
                  match.isHome ? 'Heimspiel' : 'Auswärtsspiel',
                  style: ScfText.caption.copyWith(fontSize: 10.5),
                ),
              ],
            ),
          ),
          _ScoreChip(match: match),
          const SizedBox(width: 10),
          if (match.phase != MatchPhase.beendet)
            IconButton.outlined(
              tooltip: 'Spiel beenden',
              onPressed: onFinish,
              icon: const Icon(Icons.flag_outlined),
            ),
        ],
      ),
    );
  }
}

class _ScoreChip extends StatelessWidget {
  const _ScoreChip({required this.match});

  final Match match;

  @override
  Widget build(BuildContext context) {
    int ours = 0;
    int opponents = 0;
    for (final event in match.events) {
      if (event.isOpponent) {
        if (event.type == MatchEventType.gegentor ||
            event.type == MatchEventType.gegentorSiebenMeter ||
            event.type == MatchEventType.gegentorFreiwurf) {
          opponents++;
        }
      } else if (event.type == MatchEventType.tor) {
        ours++;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: ScfColors.accentSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ScfColors.accent.withValues(alpha: 0.4)),
      ),
      child: Text(
        '$ours : $opponents',
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: ScfColors.textPrimary,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _PhaseChips extends StatelessWidget {
  const _PhaseChips({required this.match, required this.onSecondHalf});

  final Match match;
  final VoidCallback onSecondHalf;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _chip(match.phase == MatchPhase.ersteHalbzeit, '1. HZ', null),
        const SizedBox(width: 6),
        _chip(
          match.phase == MatchPhase.halbzeitpause,
          'Halbzeit',
          null,
        ),
        const SizedBox(width: 6),
        _chip(
          match.phase == MatchPhase.zweiteHalbzeit ||
              match.phase == MatchPhase.beendet,
          '2. HZ',
          match.phase == MatchPhase.ersteHalbzeit ||
                  match.phase == MatchPhase.halbzeitpause
              ? onSecondHalf
              : null,
        ),
      ],
    );
  }

  Widget _chip(bool selected, String label, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? ScfColors.accentSoft : ScfColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? ScfColors.accent.withValues(alpha: 0.5)
                : ScfColors.outline,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: selected ? ScfColors.accent : ScfColors.textSecondary,
          ),
        ),
      ),
    );
  }
}