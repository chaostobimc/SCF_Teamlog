import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_formatters.dart';
import '../../../data/models/match.dart';
import '../../../data/models/match_event.dart';
import '../../../data/models/player.dart';
import '../../../data/models/team.dart';

/// Letzte Ereignisse des Spiels, neueste zuerst.
class EventTimeline extends StatelessWidget {
  const EventTimeline({
    super.key,
    required this.match,
    required this.team,
    this.maxEntries = 30,
  });

  final Match match;
  final Team? team;
  final int maxEntries;

  @override
  Widget build(BuildContext context) {
    final events = match.events.reversed.take(maxEntries).toList();

    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, color: ScfColors.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 6),
            const Text(
              'Noch keine Aktionen erfasst',
              style: TextStyle(color: ScfColors.textSecondary, fontSize: 12.5),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: events.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        return _EventTile(
          event: events[index],
          player: team?.playerById(events[index].playerId),
        );
      },
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event, required this.player});

  final MatchEvent event;
  final Player? player;

  @override
  Widget build(BuildContext context) {
    final type = event.type;
    final tone = type == MatchEventType.tor || type.isPositive
        ? ScfColors.success
        : (type.isSanction ? ScfColors.warning : ScfColors.danger);

    final details = <String>[
      if (event.isSevenMeter) '7 m',
      if (event.goalZone != null) event.goalZone!.label,
      if (event.courtZone != null) event.courtZone!.label,
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: ScfColors.surfaceRaised,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: tone, width: 3)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              AppFormatters.clock(event.matchClockSec),
              style: const TextStyle(
                color: ScfColors.textSecondary,
                fontSize: 11.5,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Text(
            '#${player?.number ?? '?'}',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
              color: ScfColors.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              type.label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Color.lerp(tone, ScfColors.textPrimary, 0.45),
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ),
          if (details.isNotEmpty)
            Flexible(
              child: Text(
                details.join(' · '),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: ScfColors.textSecondary,
                  fontSize: 11.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
