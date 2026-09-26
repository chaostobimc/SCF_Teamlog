import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_formatters.dart';
import '../../data/models/match_event.dart';
import '../../logic/match_controller.dart';
import '../../logic/match_state.dart';
import '../../logic/providers.dart';
import '../../logic/stats_calculator.dart';
import '../../routing/app_router.dart';
import 'widgets/action_panel.dart';
import 'widgets/event_timeline.dart';
import 'widgets/goal_grid.dart';
import 'widgets/handball_court.dart';
import 'widgets/match_header.dart';
import 'widgets/player_bench.dart';

/// Live-Match-Dashboard: Spielerleiste, Feld, Tor-Raster, Aktionen.
class LiveMatchScreen extends ConsumerWidget {
  const LiveMatchScreen({super.key, required this.matchId});

  final String matchId;

  void _selectPlayerByIndex(MatchState state, MatchController controller, int index) {
    final team = state.team;
    if (team == null) return;
    final players = team.fieldPlayers
      ..sort((a, b) => a.number.compareTo(b.number));
    if (index < players.length) {
      controller.selectPlayer(players[index].id);
    }
  }

  Future<void> _showEventDialog(BuildContext context, MatchState state,
      MatchEvent event, MatchController controller) async {
    final player = state.team?.playerById(event.playerId);
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(event.isOpponent
            ? 'Gegner: ${event.type.label}'
            : event.type.label),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${AppFormatters.clock(event.matchClockSec)} · ${event.phase.label}'
              '${player == null ? '' : ' · ${player.fullName} (#${player.number})'}',
              style: ScfText.caption,
            ),
            if (event.goalZone != null || event.courtZone != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  [
                    if (event.isSevenMeter) '7 Meter',
                    if (event.goalZone != null) 'Torzone: ${event.goalZone!.label}',
                    if (event.courtZone != null)
                      'Position: ${event.courtZone!.label}',
                  ].join('  ·  '),
                  style: ScfText.caption,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Schließen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ScfColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, 'delete'),
            child: const Text('Aktion löschen'),
          ),
        ],
      ),
    );
    if (action == 'delete') controller.removeEvent(event.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(matchControllerProvider(matchId));
    final controller = ref.read(matchControllerProvider(matchId).notifier);

    ref.listen<MatchState>(
      matchControllerProvider(matchId),
      (previous, next) {
        if (previous?.noticeStamp != next.noticeStamp && next.notice != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
              content: Text(next.notice!),
              duration: const Duration(seconds: 2),
            ));
        }
      },
    );

    final team = state.team;
    final match = state.match;

    if (team == null) {
      return const Scaffold(
        body: Center(child: Text('Team zum Spiel nicht gefunden.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${team.name} – ${match.opponentName}'),
        actions: [
          IconButton(
            tooltip: 'Letzte Aktion zurücknehmen (Z)',
            onPressed: match.events.isEmpty ? null : controller.undoLastEvent,
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            tooltip: 'Auswertung',
            onPressed: () => Navigator.of(context)
                .pushNamed(AppRoutes.matchStats, arguments: matchId),
            icon: const Icon(Icons.insights_outlined),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'finish':
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Spiel beenden?'),
                      content: const Text(
                          'Die Spieluhr wird gestoppt. Statistiken bleiben erhalten.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Abbrechen'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Beenden'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) controller.finishMatch();
                  break;
                case 'shortcuts':
                  showDialog<void>(
                    context: context,
                    builder: (context) => const _ShortcutsDialog(),
                  );
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'shortcuts', child: Text('Tastaturkürzel')),
              PopupMenuItem(value: 'finish', child: Text('Spiel beenden')),
            ],
          ),
        ],
      ),
      body: CallbackShortcuts(
        bindings: {
          SingleActivator(LogicalKeyboardKey.space): controller.toggleClock,
          SingleActivator(LogicalKeyboardKey.keyZ): controller.undoLastEvent,
          SingleActivator(LogicalKeyboardKey.escape): controller.cancelPendingShot,
          SingleActivator(LogicalKeyboardKey.digit1):
              () => _selectPlayerByIndex(state, controller, 0),
          SingleActivator(LogicalKeyboardKey.digit2):
              () => _selectPlayerByIndex(state, controller, 1),
          SingleActivator(LogicalKeyboardKey.digit3):
              () => _selectPlayerByIndex(state, controller, 2),
          SingleActivator(LogicalKeyboardKey.digit4):
              () => _selectPlayerByIndex(state, controller, 3),
          SingleActivator(LogicalKeyboardKey.digit5):
              () => _selectPlayerByIndex(state, controller, 4),
          SingleActivator(LogicalKeyboardKey.digit6):
              () => _selectPlayerByIndex(state, controller, 5),
          SingleActivator(LogicalKeyboardKey.digit7):
              () => _selectPlayerByIndex(state, controller, 6),
          SingleActivator(LogicalKeyboardKey.digit8):
              () => _selectPlayerByIndex(state, controller, 7),
          SingleActivator(LogicalKeyboardKey.digit9):
              () => _selectPlayerByIndex(state, controller, 8),
        },
        child: Focus(
          autofocus: true,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              if (width >= 1100) {
                return _WideLayout(
                    state: state,
                    controller: controller,
                    onEventTap: (e) => _showEventDialog(context, state, e, controller));
              }
              if (width >= 640) {
                return _MediumLayout(
                    state: state,
                    controller: controller,
                    onEventTap: (e) => _showEventDialog(context, state, e, controller));
              }
              return _CompactLayout(
                  state: state,
                  controller: controller,
                  onEventTap: (e) => _showEventDialog(context, state, e, controller));
            },
          ),
        ),
      ),
    );
  }
}
class _WideLayout extends StatelessWidget {
  const _WideLayout({
    required this.state,
    required this.controller,
    required this.onEventTap,
  });

  final MatchState state;
  final MatchController controller;
  final void Function(MatchEvent event) onEventTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 240,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: PlayerBench(
                  team: state.team!,
                  selectedPlayerId: state.selectedPlayerId,
                  onPlayerTap: controller.selectPlayer,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: [
                MatchHeader(state: state, controller: controller),
                const SizedBox(height: 12),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Card(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                GoalGrid(
                                  onZoneTap: controller.onGoalZoneTap,
                                  zones: _zones(state),
                                  showTallies: true,
                                  selectedZone: state.pendingShot?.goalZone,
                                ),
                                const SizedBox(height: 16),
                                HandballCourt(
                                  onZoneTap: controller.onCourtZoneTap,
                                  selectedZone: _courtSelection(state),
                                  events: state.match.events,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: EventTimeline(
                              match: state.match,
                              team: state.team,
                              onEventTap: onEventTap,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 330,
            child: ActionPanel(state: state, controller: controller),
          ),
        ],
      ),
    );
  }
}

class _MediumLayout extends StatelessWidget {
  const _MediumLayout({
    required this.state,
    required this.controller,
    required this.onEventTap,
  });

  final MatchState state;
  final MatchController controller;
  final void Function(MatchEvent event) onEventTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 210,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: PlayerBench(
                  team: state.team!,
                  selectedPlayerId: state.selectedPlayerId,
                  onPlayerTap: controller.selectPlayer,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  MatchHeader(state: state, controller: controller),
                  const SizedBox(height: 10),
                  GoalGrid(
                    onZoneTap: controller.onGoalZoneTap,
                    zones: _zones(state),
                    showTallies: true,
                    selectedZone: state.pendingShot?.goalZone,
                  ),
                  const SizedBox(height: 10),
                  HandballCourt(
                    onZoneTap: controller.onCourtZoneTap,
                    selectedZone: _courtSelection(state),
                    events: state.match.events,
                  ),
                  SizedBox(
                    height: 200,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: EventTimeline(
                          match: state.match,
                          team: state.team,
                          onEventTap: onEventTap,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 300,
            child: ActionPanel(state: state, controller: controller),
          ),
        ],
      ),
    );
  }
}

class _CompactLayout extends StatelessWidget {
  const _CompactLayout({
    required this.state,
    required this.controller,
    required this.onEventTap,
  });

  final MatchState state;
  final MatchController controller;
  final void Function(MatchEvent event) onEventTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            MatchHeader(state: state, controller: controller),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                child: PlayerBench(
                  team: state.team!,
                  selectedPlayerId: state.selectedPlayerId,
                  onPlayerTap: controller.selectPlayer,
                  axis: Axis.horizontal,
                ),
              ),
            ),
            const SizedBox(height: 10),
            GoalGrid(
              onZoneTap: controller.onGoalZoneTap,
              zones: _zones(state),
              showTallies: true,
              selectedZone: state.pendingShot?.goalZone,
            ),
            const SizedBox(height: 10),
            HandballCourt(
              onZoneTap: controller.onCourtZoneTap,
              selectedZone: _courtSelection(state),
              events: state.match.events,
            ),
            const SizedBox(height: 10),
            ActionPanel(state: state, controller: controller),
            const SizedBox(height: 10),
            SizedBox(
              height: 220,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: EventTimeline(
                    match: state.match,
                    team: state.team,
                    onEventTap: onEventTap,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShortcutsDialog extends StatelessWidget {
  const _ShortcutsDialog();

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['Leertaste', 'Spieluhr starten/pause'],
      ['Z', 'Letzte Aktion zurücknehmen'],
      ['Esc', 'Wurf-Auswahl abbrechen'],
      ['1 – 9', 'Spieler nach Nummer wählen'],
    ];
    return AlertDialog(
      title: const Text('Tastaturkürzel'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 90,
                    child: Text(row[0],
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: ScfColors.textPrimary)),
                  ),
                  Expanded(child: Text(row[1], style: ScfText.caption)),
                ],
              ),
            ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    );
  }
}

Map<GoalZone, ZoneTally>? _zones(MatchState state) {
  final team = state.team;
  if (team == null) return null;
  return calculateTeamStats(state.match, team).zones;
}

CourtZone? _courtSelection(MatchState state) =>
    state.pendingShot?.courtZone ?? state.lastCourtZone;
