import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_formatters.dart';
import '../../data/models/match.dart';
import '../../logic/providers.dart';
import '../../logic/stats_calculator.dart';
import '../../routing/app_router.dart';

/// Startbildschirm: Spieluebersicht, Teams, neues Spiel.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matches = ref.watch(matchesProvider).valueOrNull ?? const [];
    final teams = ref.watch(teamsProvider).valueOrNull ?? const [];

    final running = matches.where((m) => m.status == MatchStatus.laufend).toList();
    final planned = matches.where((m) => m.status == MatchStatus.geplant).toList();
    final finished = matches.where((m) => m.status == MatchStatus.beendet).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('SCF Teamlog'),
        actions: [
          IconButton(
            tooltip: 'Teams verwalten',
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.teams),
            icon: const Icon(Icons.groups_outlined),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          final content = _MatchList(
            running: running,
            planned: planned,
            finished: finished,
            emptyHint: teams.isEmpty
                ? 'Lege zuerst ein Team an.'
                : 'Noch kein Spiel angelegt.',
          );

          return Padding(
            padding: const EdgeInsets.all(16),
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: content),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: _Sidebar(
                          teamCount: teams.length,
                          matchCount: matches.length,
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      Expanded(child: content),
                      const SizedBox(height: 12),
                      _QuickActions(teamCount: teams.length),
                    ],
                  ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).pushNamed(AppRoutes.matchSetup),
        icon: const Icon(Icons.add),
        label: const Text('Neues Spiel'),
      ),
    );
  }
}

class _MatchList extends StatelessWidget {
  const _MatchList({
    required this.running,
    required this.planned,
    required this.finished,
    required this.emptyHint,
  });

  final List<Match> running;
  final List<Match> planned;
  final List<Match> finished;
  final String emptyHint;

  @override
  Widget build(BuildContext context) {
    if (running.isEmpty && planned.isEmpty && finished.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sports_handball,
                size: 64, color: ScfColors.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(emptyHint,
                style: const TextStyle(color: ScfColors.textSecondary, fontSize: 15)),
          ],
        ),
      );
    }

    return ListView(
      children: [
        if (running.isNotEmpty) ...[
          const _SectionHeader('Laufend'),
          for (final match in running) _MatchTile(match: match),
          const SizedBox(height: 12),
        ],
        if (planned.isNotEmpty) ...[
          const _SectionHeader('Geplant'),
          for (final match in planned) _MatchTile(match: match),
          const SizedBox(height: 12),
        ],
        if (finished.isNotEmpty) ...[
          const _SectionHeader('Beendet'),
          for (final match in finished) _MatchTile(match: match),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: ScfColors.textSecondary,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _MatchTile extends ConsumerWidget {
  const _MatchTile({required this.match});

  final Match match;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final team = ref.watch(teamByIdProvider(match.ownTeamId));
    final statusColor = switch (match.status) {
      MatchStatus.laufend => ScfColors.success,
      MatchStatus.geplant => ScfColors.cyan,
      MatchStatus.beendet => ScfColors.textFaint,
    };
    final statusLabel = switch (match.status) {
      MatchStatus.laufend => 'Live',
      MatchStatus.geplant => 'Geplant',
      MatchStatus.beendet => 'Beendet',
    };
    final score = team == null || match.events.isEmpty
        ? null
        : calculateTeamStats(match, team);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          switch (match.status) {
            case MatchStatus.laufend:
              Navigator.of(context)
                  .pushNamed(AppRoutes.liveMatch, arguments: match.id);
              break;
            case MatchStatus.geplant:
            case MatchStatus.beendet:
              Navigator.of(context)
                  .pushNamed(AppRoutes.matchStats, arguments: match.id);
              break;
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${team?.name ?? 'Wir'} gegen ${match.opponentName}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${AppFormatters.date(match.date)}  ·  '
                      '${match.isHome ? 'Heim' : 'Auswärts'}  ·  '
                      '${match.halfLengthMin} min/Halbzeit  ·  $statusLabel'
                      '${score == null ? '' : '  ·  ${score.goalsFor}:${score.goalsAgainst}'}',
                      style: const TextStyle(
                        color: ScfColors.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: ScfColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.teamCount, required this.matchCount});

  final int teamCount;
  final int matchCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Übersicht',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 12),
                _StatRow(label: 'Teams', value: '$teamCount'),
                const Divider(height: 16),
                _StatRow(label: 'Spiele gesamt', value: '$matchCount'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _QuickActions(teamCount: teamCount),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(color: ScfColors.textSecondary, fontSize: 13.5)),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.teamCount});

  final int teamCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.teams),
            icon: const Icon(Icons.groups_outlined),
            label: const Text('Teams'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.playerStats),
            icon: const Icon(Icons.insights_outlined),
            label: const Text('Statistiken'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.teamEdit),
            icon: const Icon(Icons.person_add_outlined),
            label: const Text('Neu'),
          ),
        ),
      ],
    );
  }
}
