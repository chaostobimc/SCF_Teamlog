import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_breakpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_formatters.dart';
import '../../data/models/match.dart';
import '../../data/models/player.dart';
import '../../logic/match_controller.dart';
import '../../logic/match_state.dart';
import '../../logic/providers.dart';
import '../../routing/app_router.dart';
import 'widgets/action_panel.dart';
import 'widgets/event_timeline.dart';
import 'widgets/goal_grid.dart';
import 'widgets/handball_court.dart';
import 'widgets/match_header.dart';
import 'widgets/player_rail.dart';

/// Live-Erfassung: Nummernleiste links, Feld + Tor in der Mitte,
/// Aktionen rechts – alles ohne Scrollen auf dem Bildschirm.
class LiveMatchScreen extends ConsumerStatefulWidget {
  const LiveMatchScreen({super.key, required this.matchId});

  final String matchId;

  @override
  ConsumerState<LiveMatchScreen> createState() => _LiveMatchScreenState();
}

class _LiveMatchScreenState extends ConsumerState<LiveMatchScreen> {
  int _phoneTab = 0; // 0 = Ziel (Tor), 1 = Aktionen
  int _lastNoticeStamp = -1;
  bool _navigatedToStats = false;

  MatchController get _controller =>
      ref.read(matchControllerProvider(widget.matchId).notifier);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(matchControllerProvider(widget.matchId));
    final match = state.match;

    _handleNotice(state);

    if (match.status == MatchStatus.beendet && !_navigatedToStats) {
      _navigatedToStats = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(
          AppRoutes.matchStats,
          arguments: match.id,
        );
      });
    }

    final players = _controller.squadPlayers();

    return Scaffold(
      body: SafeArea(
        child: Focus(
          autofocus: true,
          onKeyEvent: (node, event) => _handleKey(event)
              ? KeyEventResult.handled
              : KeyEventResult.ignored,
          child: Column(
            children: [
              MatchHeader(
                state: state,
                onEditTime: () => _showTimeDialog(state),
                onPhaseAction: _controller.startSecondHalf,
                onFinish: _confirmFinish,
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth >= AppBreakpoints.medium) {
                      return _WideLayout(
                        state: state,
                        players: players,
                        showEvents: constraints.maxHeight >= 540,
                        onDeleteEvent: _confirmDelete,
                        controller: _controller,
                      );
                    }
                    return _PhoneLayout(
                      state: state,
                      players: players,
                      phoneTab: _phoneTab,
                      onTabChanged: (i) => setState(() => _phoneTab = i),
                      controller: _controller,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _BottomBar(
        state: state,
        controller: _controller,
        onShowTimeline: () => _showTimelineSheet(state),
        onShowStats: () => Navigator.of(context).pushNamed(
          AppRoutes.matchStats,
          arguments: match.id,
        ),
      ),
    );
  }

  void _handleNotice(MatchState state) {
    final stamp = state.noticeStamp;
    if (stamp != null && stamp != _lastNoticeStamp && state.notice != null) {
      _lastNoticeStamp = stamp;
      final message = state.notice!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      });
    }
  }

  bool _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final state = ref.read(matchControllerProvider(widget.matchId));

    if (event.logicalKey == LogicalKeyboardKey.space) {
      _controller.toggleClock();
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyZ) {
      _controller.undoLastEvent();
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (state.pendingShot != null) {
        _controller.cancelPendingShot();
      }
      return true;
    }
    final digit = event.logicalKey.keyLabel;
    if (digit.length == 1 && int.tryParse(digit) != null) {
      final players = _controller.squadPlayers();
      final index = int.parse(digit) - 1;
      if (index >= 0 && index < players.length) {
        _controller.selectPlayer(players[index].id);
        return true;
      }
    }
    return false;
  }

  void _showTimeDialog(MatchState state) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _TimeAdjustDialog(
        state: state,
        controller: _controller,
      ),
    );
  }

  void _confirmFinish() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Spiel beenden?'),
        content: const Text('Die Uhr wird gestoppt, das Ergebnis gespeichert.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              _controller.finishMatch();
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Beenden'),
          ),
        ],
      ),
    );
  }

  void _showTimelineSheet(MatchState state) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ScfColors.surfaceRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      isScrollControlled: true,
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height * 0.72,
        child: EventTimeline(
          match: state.match,
          team: state.team,
          onEventTap: (event) {
            Navigator.of(sheetContext).pop();
            _confirmDelete(event.id);
          },
        ),
      ),
    );
  }

  void _confirmDelete(String eventId) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ereignis löschen?'),
        content: const Text(
          'Das Ereignis wird entfernt. Spätere Ereignisse bleiben unverändert.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ScfColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              _controller.removeEvent(eventId);
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Weitlayout

class _WideLayout extends StatelessWidget {
  const _WideLayout({
    required this.state,
    required this.players,
    required this.showEvents,
    required this.onDeleteEvent,
    required this.controller,
  });

  final MatchState state;
  final List<Player> players;
  final bool showEvents;
  final ValueChanged<String> onDeleteEvent;
  final MatchController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PlayerRail(
          players: players,
          selectedPlayerId: state.selectedPlayerId,
          onPlayerTap: controller.selectPlayer,
        ),
        Expanded(
          flex: 55,
          child: Column(
            children: [
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 8, 6, 4),
                  child: HandballCourt(
                    onZoneTap: controller.onCourtZoneTap,
                    selectedZone: state.lastCourtZone,
                    events: state.match.events,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
                  child: Center(
                    child: GoalGrid(
                      onZoneTap: controller.onGoalZoneTap,
                      selectedZone: state.pendingShot?.goalZone,
                      enabled: state.match.status == MatchStatus.laufend,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 45,
          child: Column(
            children: [
              Expanded(
                child: ActionPanel(state: state, controller: controller),
              ),
              if (showEvents)
                SizedBox(
                  height: 180,
                  child: EventTimeline(
                    match: state.match,
                    team: state.team,
                    onEventTap: (event) => onDeleteEvent(event.id),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------- Telefonlayout

class _PhoneLayout extends StatelessWidget {
  const _PhoneLayout({
    required this.state,
    required this.players,
    required this.phoneTab,
    required this.onTabChanged,
    required this.controller,
  });

  final MatchState state;
  final List<Player> players;
  final int phoneTab;
  final ValueChanged<int> onTabChanged;
  final MatchController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PlayerRail(
          players: players,
          selectedPlayerId: state.selectedPlayerId,
          onPlayerTap: controller.selectPlayer,
          width: 54,
        ),
        Expanded(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(
                      value: 0,
                      label: Text('Ziel'),
                      icon: Icon(Icons.gps_fixed),
                    ),
                    ButtonSegment(
                      value: 1,
                      label: Text('Aktionen'),
                      icon: Icon(Icons.sports_handball),
                    ),
                  ],
                  selected: {phoneTab},
                  onSelectionChanged: (selection) =>
                      onTabChanged(selection.first),
                  showSelectedIcon: false,
                ),
              ),
              Expanded(
                child: phoneTab == 0
                    ? Column(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(6, 0, 6, 4),
                              child: HandballCourt(
                                onZoneTap: controller.onCourtZoneTap,
                                selectedZone: state.lastCourtZone,
                                events: state.match.events,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
                            child: GoalGrid(
                              onZoneTap: controller.onGoalZoneTap,
                              selectedZone: state.pendingShot?.goalZone,
                              enabled:
                                  state.match.status == MatchStatus.laufend,
                            ),
                          ),
                        ],
                      )
                    : ActionPanel(
                        state: state,
                        controller: controller,
                        compact: true,
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------- Unterleiste

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.state,
    required this.onShowTimeline,
    required this.onShowStats,
    required this.controller,
  });

  final MatchState state;
  final VoidCallback onShowTimeline;
  final VoidCallback onShowStats;
  final MatchController controller;

  @override
  Widget build(BuildContext context) {
    final running = state.running;

    return Container(
      color: ScfColors.surface,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: Row(
        children: [
          IconButton.filledTonal(
            tooltip: 'Verlauf',
            onPressed: onShowTimeline,
            icon: Badge(
              isLabelVisible: state.match.events.isNotEmpty,
              label: Text('${state.match.events.length}'),
              child: const Icon(Icons.history),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.icon(
              onPressed:
                  state.match.events.isEmpty ? null : onShowStats,
              icon: const Icon(Icons.analytics_outlined, size: 18),
              label: const Text('Spielstatistik'),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: 'Rückgängig (Z)',
            onPressed:
                state.match.events.isEmpty ? controller.undoLastEvent : null,
            icon: const Icon(Icons.undo),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: running ? 'Uhr anhalten' : 'Uhr starten',
            onPressed: controller.toggleClock,
            style: IconButton.styleFrom(
              backgroundColor: running ? ScfColors.danger : ScfColors.success,
              foregroundColor: Colors.black,
            ),
            icon: Icon(running ? Icons.pause : Icons.play_arrow),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ Zeiteinstellung

class _TimeAdjustDialog extends StatefulWidget {
  const _TimeAdjustDialog({required this.state, required this.controller});

  final MatchState state;
  final MatchController controller;

  @override
  State<_TimeAdjustDialog> createState() => _TimeAdjustDialogState();
}

class _TimeAdjustDialogState extends State<_TimeAdjustDialog> {
  late int _target;

  @override
  void initState() {
    super.initState();
    _target = widget.state.match.phaseElapsedSec;
  }

  @override
  Widget build(BuildContext context) {
    final phaseName = widget.state.match.phase.label;

    return AlertDialog(
      title: Text('Spielzeit · $phaseName'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            AppFormatters.clock(_target),
            style: ScfText.numberBig.copyWith(fontSize: 44),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton(
                onPressed: () => setState(() => _target -= 10),
                child: const Text('−10 s'),
              ),
              OutlinedButton(
                onPressed: () => setState(() => _target += 10),
                child: const Text('+10 s'),
              ),
              OutlinedButton(
                onPressed: () => setState(() => _target -= 60),
                child: const Text('−1 min'),
              ),
              OutlinedButton(
                onPressed: () => setState(() => _target += 60),
                child: const Text('+1 min'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Wird sofort auf die laufende Phase übernommen.',
            style: ScfText.caption.copyWith(fontSize: 11),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () {
            widget.controller.setPeriodClock(_target);
            Navigator.of(context).pop();
          },
          child: const Text('Übernehmen'),
        ),
      ],
    );
  }
}
