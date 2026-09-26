import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_formatters.dart';
import '../../../data/models/match.dart';
import '../../../logic/match_controller.dart';
import '../../../logic/match_state.dart';
import '../../../logic/stats_calculator.dart';

/// Kopfzeile des Live-Screens: Paarung, Spielstand, Spieluhr, Steuerung,
/// laufende Zeitstrafen.
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
    final stats =
        team == null ? null : calculateTeamStats(match, team);

    final homeName = match.isHome ? (team?.name ?? 'Wir') : match.opponentName;
    final guestName = match.isHome ? match.opponentName : (team?.name ?? 'Wir');
    final homeGoals =
        match.isHome ? stats?.goalsFor ?? 0 : stats?.goalsAgainst ?? 0;
    final guestGoals =
        match.isHome ? stats?.goalsAgainst ?? 0 : stats?.goalsFor ?? 0;
    final penalties = activePenalties(match);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _TeamName(
                    name: homeName,
                    color: match.isHome
                        ? team?.primaryColor ?? ScfColors.accent
                        : ScfColors.cyan,
                  ),
                ),
                _ScoreBlock(home: homeGoals, guest: guestGoals),
                Expanded(
                  child: _TeamName(
                    name: guestName,
                    color: match.isHome
                        ? ScfColors.cyan
                        : team?.primaryColor ?? ScfColors.accent,
                    alignRight: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _PhasePill(phase: match.phase),
                const SizedBox(width: 12),
                Text(
                  AppFormatters.clock(match.matchClockSec),
                  style: ScfText.numberBig.copyWith(fontSize: 28),
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
                _IconButton(
                  tooltip: 'Auszeit',
                  icon: Icons.free_breakfast_outlined,
                  onTap: controller.timeout,
                ),
                const SizedBox(width: 8),
                _ClockButton(state: state, controller: controller),
              ],
            ),
            if (penalties.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final penalty in penalties)
                    _PenaltyChip(
                      penalty: penalty,
                      matchClockSec: match.matchClockSec,
                      playerNumber: team
                          ?.playerById(penalty.event.playerId)?.number,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScoreBlock extends StatelessWidget {
  const _ScoreBlock({required this.home, required this.guest});

  final int home;
  final int guest;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      decoration: BoxDecoration(
        color: ScfColors.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ScfColors.outline),
      ),
      child: Text(
        '$home : $guest',
        style: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
          color: ScfColors.textPrimary,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _TeamName extends StatelessWidget {
  const _TeamName({
    required this.name,
    required this.color,
    this.alignRight = false,
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
        if (!alignRight) ...[
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
        ],
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
        if (alignRight) ...[
          const SizedBox(width: 8),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ],
      ],
    );
  }
}

class _PhasePill extends StatelessWidget {
  const _PhasePill({required this.phase});

  final MatchPhase phase;

  @override
  Widget build(BuildContext context) {
    final color = switch (phase) {
      MatchPhase.ersteHalbzeit => ScfColors.cyan,
      MatchPhase.halbzeitpause => ScfColors.warning,
      MatchPhase.zweiteHalbzeit => ScfColors.cyan,
      MatchPhase.beendet => ScfColors.textFaint,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        phase.label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _PenaltyChip extends StatelessWidget {
  const _PenaltyChip({
    required this.penalty,
    required this.matchClockSec,
    required this.playerNumber,
  });

  final ActivePenalty penalty;
  final int matchClockSec;
  final int? playerNumber;

  @override
  Widget build(BuildContext context) {
    final remaining = penalty.remainingSec(matchClockSec);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: ScfColors.dangerSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ScfColors.danger.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, size: 13, color: ScfColors.danger),
          const SizedBox(width: 5),
          Text(
            'Nr. ${playerNumber ?? '?'} · ${AppFormatters.clock(remaining)}',
            style: const TextStyle(
              color: ScfColors.textPrimary,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: ScfColors.surfaceRaised,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ScfColors.outline),
          ),
          child: Icon(icon, size: 20, color: ScfColors.textSecondary),
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
      width: 132,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: finished
              ? ScfColors.surfaceRaised
              : (running ? ScfColors.danger : ScfColors.success),
          foregroundColor:
              finished ? ScfColors.textSecondary : Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: finished ? null : controller.toggleClock,
        icon: Icon(
          finished ? Icons.flag : (running ? Icons.pause : Icons.play_arrow),
          size: 20,
        ),
        label: Text(
          finished ? 'Ende' : (running ? 'Pause' : 'Start'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
