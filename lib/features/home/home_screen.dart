import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_formatters.dart';
import '../../data/models/match.dart';
import '../../data/models/match_event.dart';
import '../../logic/providers.dart';
import '../../routing/app_router.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(matchesProvider);
    final team = ref.watch(scfTeamProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: ScfColors.accent,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'SC',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SCF Teamlog',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 21,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            'SC Freising · Handball Live-Statistik',
                            style: ScfText.caption,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Kader verwalten',
                      onPressed: () => Navigator.of(context)
                          .pushNamed(AppRoutes.squad),
                      icon: const Icon(Icons.groups_outlined),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _QuickActions(teamPlayerCount: team.players.length),
                const SizedBox(height: 22),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'SPIELVERLAUF',
                        style: ScfText.sectionLabel,
                      ),
                    ),
                    matchesAsync.maybeWhen(
                      data: (matches) => Text(
                        '${matches.length} Spiele',
                        style: ScfText.caption.copyWith(fontSize: 11),
                      ),
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                matchesAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, stackTrace) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Fehler beim Laden: $error'),
                    ),
                  ),
                  data: (matches) => matches.isEmpty
                      ? const _EmptyHistory()
                      : Column(
                          children: [
                            for (final match in matches)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _MatchRow(match: match),
                              ),
                          ],
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

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.teamPlayerCount});

  final int teamPlayerCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: _ActionCard(
            icon: Icons.play_arrow_rounded,
            title: 'Spiel starten',
            subtitle: 'Live erfassen',
            color: ScfColors.accent,
            onTap: () =>
                Navigator.of(context).pushNamed(AppRoutes.matchSetup),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: _ActionCard(
            icon: Icons.people_outline,
            title: 'Kader',
            subtitle: '$teamPlayerCount Spieler',
            color: ScfColors.cyan,
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.squad),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: _ActionCard(
            icon: Icons.leaderboard_outlined,
            title: 'Statistik',
            subtitle: 'Alle Zeiten',
            color: ScfColors.violet,
            onTap: () =>
                Navigator.of(context).pushNamed(AppRoutes.playerStats),
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: ScfText.caption.copyWith(fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(
              Icons.sports_handball,
              size: 42,
              color: ScfColors.textFaint,
            ),
            const SizedBox(height: 12),
            const Text(
              'Noch keine Spiele',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 6),
            const Text(
              'Starte oben dein erstes Live-Spiel –\n'
              'jede Aktion landet sofort in der Statistik.',
              textAlign: TextAlign.center,
              style: ScfText.caption,
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchRow extends StatelessWidget {
  const _MatchRow({required this.match});

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
    final result = '$ours : $opponents';
    final live = match.status == MatchStatus.laufend;
    final phaseLabel = match.phase.label;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).pushNamed(
          AppRoutes.matchStats,
          arguments: match.id,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 42,
                decoration: BoxDecoration(
                  color: live
                      ? ScfColors.success
                      : match.status == MatchStatus.beendet
                          ? ScfColors.accent
                          : ScfColors.textFaint,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      match.opponentName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${AppFormatters.date(match.date)} · $phaseLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ScfText.caption.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    result,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (live) ...[
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: ScfColors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Live',
                          style: ScfText.caption.copyWith(
                            fontSize: 10.5,
                            color: ScfColors.success,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ] else
                        Text(
                          'Ansehen',
                          style: ScfText.caption.copyWith(fontSize: 10.5),
                        ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: ScfColors.textFaint,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
