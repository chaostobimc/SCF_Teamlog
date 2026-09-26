import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_formatters.dart';
import '../../../data/models/match.dart';
import '../../../data/models/team.dart';
import '../../../logic/match_controller.dart';
import '../../../logic/match_state.dart';
import '../../../logic/stats_calculator.dart';

/// Kopfzeile des Live-Screens: Paarung, Spielstand, Spieluhr, Steuerung.
class MatchHeader extends StatelessWidget {
  const MatchHeader({
    super.key,
    required this.state,
    required this.controller,
  });

  final MatchState state;
  final MatchController controller;

  @override
  Widget build(BuildContext context) {
    final match = state.match;
    final team = state.team;
    final stats = team == null
        ? null
        : calculateTeamStats(match, team);

    final homeName = match.isHome ? (team?.name ?? 'Wir') : match.opponentName;
    final guestName = match.isHome ? match.opponentName : (team?.name ?? 'Wir');
    final homeGoals = match.isHome ? stats?.goalsFor ?? 0 : stats?.goalsAgainst ?? 0;
    final guestGoals = match.isHome ? stats?.goalsAgainst ?? 0 : stats?.goalsFor ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _TeamBlock(
                    name: homeName,
                    color: match.isHome
                        ? team?.primaryColor ?? ScfColors.accent
                        : ScfColors.info,
                    alignRight: false,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    '$homeGoals : $guestGoals',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: ScfColors.textPrimary,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                Expanded(
                  child: _TeamBlock(
                    name: guestName,
                    color: match.isHome
                        ? ScfColors.info
                        : team?.primaryColor ?? ScfColors.accent,
                    alignRight: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _PhaseChip(phase: match.phase),
                const SizedBox(width: 10),
                Text(
                  AppFormatters.clock(match.matchClockSec),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: ScfColors.textPrimary,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const Spacer(),
                if (match.phase == MatchPhase.halbzeitpause)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilledButton.icon(
                      onPressed: controller.startSecondHalf,
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: const Text('2. Halbzeit'),
                    ),
                  ),
                _ClockButton(state: state, controller: controller),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ClockButton extends StatelessWidget {
  const _ClockButton({required this.state, required this.controller});

  final MatchState state;
  final MatchController controller;

  @override
  Widget build(BuildContext context) {
    final finished = state.match.status == MatchStatus.beendet ||
        state.match.phase == MatchPhase.beendet;
    final running = state.running;

    return SizedBox(
      height: 48,
      width: 120,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: finished
              ? ScfColors.outline
              : (running ? ScfColors.danger : ScfColors.success),
          foregroundColor: ScfColors.textPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: finished ? null : controller.toggleClock,
        icon: Icon(
          finished
              ? Icons.flag
              : (running ? Icons.pause : Icons.play_arrow),
          size: 22,
        ),
        label: Text(
          finished ? 'Ende' : (running ? 'Pause' : 'Start'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _PhaseChip extends StatelessWidget {
  const _PhaseChip({required this.phase});

  final MatchPhase phase;

  @override
  Widget build(BuildContext context) {
    final color = switch (phase) {
      MatchPhase.ersteHalbzeit => ScfColors.info,
      MatchPhase.halbzeitpause => ScfColors.warning,
      MatchPhase.zweiteHalbzeit => ScfColors.info,
      MatchPhase.beendet => ScfColors.outline,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        phase.label,
        style: TextStyle(
          color: Color.lerp(color, ScfColors.textPrimary, 0.5),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TeamBlock extends StatelessWidget {
  const _TeamBlock({
    required this.name,
    required this.color,
    required this.alignRight,
  });

  final String name;
  final Color color;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment:
          alignRight ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (!alignRight)
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        Flexible(
          child: Text(
            name,
            overflow: TextOverflow.ellipsis,
            textAlign: alignRight ? TextAlign.right : TextAlign.left,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: ScfColors.textPrimary,
            ),
          ),
        ),
        if (alignRight)
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.only(left: 8),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
      ],
    );
  }
}
