import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_formatters.dart';
import '../../core/utils/repaint_capture.dart';
import '../../data/export/export_service.dart';
import '../../data/models/match.dart';
import '../../data/models/player.dart';
import '../../data/models/team.dart';
import '../../logic/providers.dart';
import '../../logic/stats_calculator.dart';

class PlayerStatsArgs {
  const PlayerStatsArgs({this.team, this.playerId});

  final Team? team;
  final String? playerId;
}

/// Spielerstatistiken: pro Spiel oder ueber alle Spiele.
class PlayerStatsScreen extends ConsumerStatefulWidget {
  const PlayerStatsScreen({super.key, this.args});

  final PlayerStatsArgs? args;

  @override
  ConsumerState<PlayerStatsScreen> createState() => _PlayerStatsScreenState();
}

class _PlayerStatsScreenState extends ConsumerState<PlayerStatsScreen> {
  Team? _team;
  String? _playerId;

  /// 'alltime' oder die Match-ID.
  String _scope = 'alltime';

  final GlobalKey _statsKey = GlobalKey();
  static final _exportService = ExportService();

  @override
  void initState() {
    super.initState();
    _team = widget.args?.team;
    _playerId = widget.args?.playerId;
  }

  List<Match> _teamMatches() {
    final team = _team;
    if (team == null) return const [];
    final matches = (ref.watch(matchesProvider).valueOrNull ?? const <Match>[])
        .where((m) => m.ownTeamId == team.id && m.events.isNotEmpty)
        .toList();
    return matches;
  }

  @override
  Widget build(BuildContext context) {
    final teams = ref.watch(teamsProvider).valueOrNull ?? const <Team>[];
    if (teams.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Noch keine Teams angelegt.')),
      );
    }
    final team = _team ?? (_team = teams.first);

    final players = [...team.players]
      ..sort((a, b) => a.number.compareTo(b.number));
    Player? player;
    for (final p in players) {
      if (p.id == _playerId) player = p;
    }
    player ??= players.isNotEmpty ? players.first : null;

    final matches = _teamMatches();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spielerstatistiken'),
        actions: [
          if (player != null)
            IconButton(
              tooltip: 'Als Bild exportieren',
              onPressed: () async {
                try {
                  final bytes = await captureWidgetPng(_statsKey);
                  await _deliver(context, 'spieler_${player!.number}.png', bytes,
                      'image/png');
                } catch (error) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Export fehlgeschlagen: $error')));
                }
              },
              icon: const Icon(Icons.image_outlined),
            ),
          if (player != null)
            IconButton(
              tooltip: 'Als Tabelle exportieren (CSV)',
              onPressed: () async {
                final csv =
                    _exportService.playerMatchesCsv(matches, player!);
                await _deliver(
                    context,
                    'spieler_${player!.number}.csv',
                    Uint8List.fromList(utf8.encode(csv)),
                    'text/csv');
              },
              icon: const Icon(Icons.table_rows_outlined),
            ),
        ],
      ),
      body: player == null
          ? const Center(child: Text('Keine Spieler im Kader.'))
          : LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 900;
                final detail = RepaintBoundary(
                  key: _statsKey,
                  child: ColoredBox(
                    color: ScfColors.background,
                    child: _PlayerDetail(
                      team: team,
                      player: player!,
                      matches: matches,
                      scope: _scope,
                      onScopeChanged: (scope) =>
                          setState(() => _scope = scope),
                    ),
                  ),
                );
                final list = _PlayerList(
                  team: team,
                  players: players,
                  selectedId: player!.id,
                  onSelected: (id) => setState(() => _playerId = id),
                  matches: matches,
                );

                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(width: 280, child: list),
                            const SizedBox(width: 16),
                            Expanded(child: SingleChildScrollView(child: detail)),
                          ],
                        )
                      : ListView(
                          children: [
                            SizedBox(
                              height: 240,
                              child: Card(child: list),
                            ),
                            const SizedBox(height: 12),
                            detail,
                          ],
                        ),
                );
              },
            ),
    );
  }

  Future<void> _deliver(
      BuildContext context, String name, Uint8List bytes, String mime) async {
    try {
      if (Platform.isAndroid) {
        await Share.shareXFiles(
          [XFile.fromData(bytes, mimeType: mime)],
          fileNameOverrides: [name],
        );
        return;
      }
      final docs = await getApplicationDocumentsDirectory();
      final folder =
          Directory('${docs.path}${Platform.pathSeparator}SCF_Teamlog');
      await folder.create(recursive: true);
      final file = File('${folder.path}${Platform.pathSeparator}$name');
      await file.writeAsBytes(bytes);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gespeichert: ${file.path}')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export fehlgeschlagen: $error')),
        );
      }
    }
  }
}

class _PlayerList extends StatelessWidget {
  const _PlayerList({
    required this.team,
    required this.players,
    required this.selectedId,
    required this.onSelected,
    required this.matches,
  });

  final Team team;
  final List<Player> players;
  final String selectedId;
  final ValueChanged<String> onSelected;
  final List<Match> matches;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          for (final player in players)
            ListTile(
              selected: player.id == selectedId,
              selectedTileColor: ScfColors.accentSoft,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              leading: CircleAvatar(
                backgroundColor: player.position == PlayerPosition.torwart
                    ? ScfColors.cyanSoft
                    : ScfColors.accentSoft,
                child: Text(
                  '${player.number}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: player.position == PlayerPosition.torwart
                        ? ScfColors.cyan
                        : ScfColors.accent,
                  ),
                ),
              ),
              title: Text(player.shortName,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                '${allTimeStatsForPlayer(matches, player).goals} Tore',
                style: const TextStyle(
                    color: ScfColors.textSecondary, fontSize: 11.5),
              ),
              onTap: () => onSelected(player.id),
            ),
        ],
      ),
    );
  }
}

class _PlayerDetail extends StatelessWidget {
  const _PlayerDetail({
    required this.team,
    required this.player,
    required this.matches,
    required this.scope,
    required this.onScopeChanged,
  });

  final Team team;
  final Player player;
  final List<Match> matches;
  final String scope;
  final ValueChanged<String> onScopeChanged;

  @override
  Widget build(BuildContext context) {
    final isAllTime = scope == 'alltime';
    final stats = isAllTime
        ? allTimeStatsForPlayer(matches, player)
        : statsForPlayer(
            matches.firstWhere((m) => m.id == scope, orElse: () => matches.isEmpty
                ? Match(
                    id: 'none',
                    ownTeamId: team.id,
                    opponentName: '-',
                    date: DateTime(2000),
                    isHome: true,
                  )
                : matches.first),
            player);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: player.position == PlayerPosition.torwart
                        ? ScfColors.cyanSoft
                        : ScfColors.accentSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${player.number}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: player.position == PlayerPosition.torwart
                          ? ScfColors.cyan
                          : ScfColors.accent,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(player.fullName,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800)),
                      Text(
                        player.position.label +
                            (player.gameRole == PlayerGameRole.keine
                                ? ''
                                : ' · ${player.gameRole.label}'),
                        style: ScfText.caption,
                      ),
                    ],
                  ),
                ),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                        value: 'alltime', label: Text('Alle Spiele')),
                    ButtonSegment(value: 'match', label: Text('Ein Spiel')),
                  ],
                  selected: {isAllTime ? 'alltime' : 'match'},
                  onSelectionChanged: (selection) {
                    final value = selection.first;
                    if (value == 'alltime') {
                      onScopeChanged('alltime');
                    } else if (matches.isNotEmpty) {
                      onScopeChanged(
                          scope == 'alltime' ? matches.first.id : scope);
                    }
                  },
                ),
                if (!isAllTime && matches.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  DropdownButton<String>(
                    value: matches.any((m) => m.id == scope)
                        ? scope
                        : matches.first.id,
                    dropdownColor: ScfColors.surfaceRaised,
                    items: [
                      for (final match in matches)
                        DropdownMenuItem(
                          value: match.id,
                          child: Text(
                            '${AppFormatters.date(match.date)} · ${match.opponentName}',
                            style: const TextStyle(fontSize: 12.5),
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) onScopeChanged(value);
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _StatTile('Würfe', '${stats.shots}', Icons.sports_handball),
            _StatTile('Tore', '${stats.goals}', Icons.check_circle,
                color: ScfColors.success),
            _StatTile(
                'Quote', AppFormatters.percent(stats.shotRatio), Icons.percent),
            _StatTile('7-Meter',
                '${stats.goalsSevenMeter}/${stats.shotsSevenMeter}', Icons.flag),
            _StatTile(
                'Paraden', '${stats.saves}', Icons.back_hand,
                color: ScfColors.cyan),
            _StatTile('P-Quote', AppFormatters.percent(stats.saveRatio),
                Icons.shield),
            _StatTile('Ballverluste', '${stats.ballLosses}', Icons.report,
                color: ScfColors.danger),
            _StatTile('Technikfehler', '${stats.technicalErrors}',
                Icons.directions_walk),
            _StatTile('2 min', '${stats.twoMinutes}', Icons.timer,
                color: ScfColors.accent),
          ],
        ),
        const SizedBox(height: 12),
        if (isAllTime) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 8),
                    child: Text('Je Spiel',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: _PerMatchTable(matches: matches, player: player),
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Sanktionen & Details',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 10),
                  _DetailRow('Gelbe Karten', '${stats.yellowCards}'),
                  _DetailRow('2-Minuten-Strafen', '${stats.twoMinutes}'),
                  _DetailRow('Rote Karten', '${stats.redCards}'),
                  _DetailRow('Blaue Karten', '${stats.blueCards}'),
                  _DetailRow('7m herausgeholt', '${stats.sevenMeterWon}'),
                  _DetailRow('Duelle gewonnen', '${stats.duelsWon}'),
                  _DetailRow('Gefoult worden', '${stats.foulsSuffered}'),
                  _DetailRow('Gegentore', '${stats.conceded}'),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile(this.label, this.value, this.icon, {this.color});

  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ScfColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ScfColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color ?? ScfColors.textSecondary),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: ScfColors.textPrimary,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: ScfText.caption),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: ScfText.caption),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: ScfColors.textPrimary)),
        ],
      ),
    );
  }
}

class _PerMatchTable extends StatelessWidget {
  const _PerMatchTable({required this.matches, required this.player});

  final List<Match> matches;
  final Player player;

  @override
  Widget build(BuildContext context) {
    return DataTable(
      headingRowHeight: 36,
      dataRowMinHeight: 40,
      dataRowMaxHeight: 44,
      columns: const [
        DataColumn(label: Text('Datum')),
        DataColumn(label: Text('Gegner')),
        DataColumn(label: Text('Würfe'), numeric: true),
        DataColumn(label: Text('Tore'), numeric: true),
        DataColumn(label: Text('Quote'), numeric: true),
        DataColumn(label: Text('7m'), numeric: true),
        DataColumn(label: Text('Paraden'), numeric: true),
        DataColumn(label: Text('GT'), numeric: true),
        DataColumn(label: Text('BV'), numeric: true),
        DataColumn(label: Text('2min'), numeric: true),
      ],
      rows: [
        for (final match in matches)
          DataRow(cells: [
            DataCell(Text(AppFormatters.date(match.date))),
            DataCell(Text(match.opponentName)),
            DataCell(Text('${statsForPlayer(match, player).shots}')),
            DataCell(Text('${statsForPlayer(match, player).goals}',
                style: const TextStyle(fontWeight: FontWeight.w800))),
            DataCell(Text(
                AppFormatters.percent(statsForPlayer(match, player).shotRatio))),
            DataCell(Text('${statsForPlayer(match, player).goalsSevenMeter}')),
            DataCell(Text('${statsForPlayer(match, player).saves}')),
            DataCell(Text('${statsForPlayer(match, player).conceded}')),
            DataCell(Text('${statsForPlayer(match, player).ballLosses}')),
            DataCell(Text('${statsForPlayer(match, player).twoMinutes}')),
          ]),
      ],
    );
  }
}
