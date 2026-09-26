import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
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
            ..showSnackBar(SnackBar(content: Text(next.notice!), duration: const Duration(seconds: 2)));
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
        title: Text('${team?.name ?? 'Team'} - ${match.opponentName}'),
        actions: [
          IconButton(
            tooltip: 'Letzte Aktion zurücknehmen',
            onPressed: match.events.isEmpty ? null : controller.undoLastEvent,
            icon: const Icon(Icons.undo),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'stats':
                  Navigator.of(context).pushNamed(AppRoutes.matchStats, arguments: matchId);
                  break;
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
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'stats', child: Text('Auswertung anzeigen')),
              PopupMenuItem(value: 'finish', child: Text('Spiel beenden')),
            ],
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          if (width >= 1100) {
            return _WideLayout(state: state, controller: controller);
          }
          if (width >= 640) {
            return _MediumLayout(state: state, controller: controller);
          }
          return _CompactLayout(state: state, controller: controller);
        },
      ),
    );
  }
}

class _WideLayout extends StatelessWidget {
  const _WideLayout({required this.state, required this.controller});

  final MatchState state;
  final MatchController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 235,
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
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              children: [
                                GoalGrid(
                                  onZoneTap: controller.onGoalZoneTap,
                                  zones: _zones(state),
                                  showTallies: true,
                                ),
                                const SizedBox(height: 14),
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
            width: 320,
            child: ActionPanel(state: state, controller: controller),
          ),
        ],
      ),
    );
  }
}

class _MediumLayout extends StatelessWidget {
  const _MediumLayout({required this.state, required this.controller});

  final MatchState state;
  final MatchController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 205,
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
                  ),
                  const SizedBox(height: 10),
                  HandballCourt(
                    onZoneTap: controller.onCourtZoneTap,
                    selectedZone: _courtSelection(state),
                    events: state.match.events,
                  ),
                  SizedBox(
                    height: 190,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: EventTimeline(match: state.match, team: state.team),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 280,
            child: ActionPanel(state: state, controller: controller),
          ),
        ],
      ),
    );
  }
}

class _CompactLayout extends StatelessWidget {
  const _CompactLayout({required this.state, required this.controller});

  final MatchState state;
  final MatchController controller;

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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
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
            ),
            const SizedBox(height: 10),
            HandballCourt(
              onZoneTap: controller.onCourtZoneTap,
              selectedZone: _courtSelection(state),
              events: state.match.events,
            ),
            const SizedBox(height: 10),
            ActionPanel(state: state, controller: controller),
          ],
        ),
      ),
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
