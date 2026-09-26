import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_formatters.dart';
import '../../../data/models/match.dart';
import '../../../data/models/match_event.dart';
import '../../../data/models/player.dart';
import '../../../data/models/team.dart';

/// Letzte Ereignisse des Spiels, neueste zuerst. Tippen oeffnet Korrektur.
class EventTimeline extends StatelessWidget {
  const EventTimeline({
    super.key,
    required this.match,
    required this.team,
    this.onEventTap,
    this.maxEntries = 40,
  });

  final Match match;
  final Team? team;
  final void Function(MatchEvent event)? onEventTap;
  final int maxEntries;

  @override
  Widget build(BuildContext context) {
    final events = match.events.reversed.take(maxEntries).toList();

    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timeline,
                size: 34, color: ScfColors.textFaint.withValues(alpha: 0.6)),
            const SizedBox(height: 8),
            const Text(
              'Noch keine Aktionen erfasst',
              style: TextStyle(color: ScfColors.textFaint, fontSize: 12.5),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: events.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final event = events[index];
        return _EventTile(
          event: event,
          player: team?.playerById(event.playerId),
          onTap: onEventTap == null ? null : () => onEventTap!(event),
        );
      },
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({
    required this.event,
    required this.player,
    this.onTap,
  });

  final MatchEvent event;
  final Player? player;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final type = event.type;
    final Color tone;
    if (event.isOpponent) {
      tone = ScfColors.cyan;
    } else if (type == MatchEventType.tor || type.isPositive) {
      tone = ScfColors.success;
    } else if (type.isSanction) {
      tone = ScfColors.warning;
    } else {
      tone = ScfColors.danger;
    }

    final details = <String>[
      if (event.isSevenMeter) '7 m',
      if (event.goalZone != null) event.goalZone!.label,
      if (event.courtZone != null) event.courtZone!.label,
    ];

    return Material(
      color: ScfColors.surfaceRaised,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border(left: BorderSide(color: tone, width: 3)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 42,
                child: Text(
                  AppFormatters.clock(event.matchClockSec),
                  style: const TextStyle(
                    color: ScfColors.textFaint,
                    fontSize: 11,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              if (event.isOpponent)
                const Icon(Icons.person_outline,
                    size: 13, color: ScfColors.cyan)
              else
                Text(
                  '#${player?.number ?? '?'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: ScfColors.textPrimary,
                  ),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  event.isOpponent ? 'Gegner: ${type.label}' : type.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color.lerp(tone, ScfColors.textPrimary, 0.45),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              if (details.isNotEmpty)
                Flexible(
                  child: Text(
                    details.join(' · '),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ScfColors.textFaint,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
