import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_formatters.dart';
import '../../data/export/export_service.dart';
import '../../data/models/match.dart';
import '../../data/models/match_event.dart';
import '../../data/models/player.dart';
import '../../data/models/team.dart';
import '../../logic/providers.dart';
import '../../logic/stats_calculator.dart';
import '../../routing/app_router.dart';

/// Auswertung eines Spiels: Live-Statistik, Spielertabelle, Export.
class MatchStatsScreen extends ConsumerWidget {
  const MatchStatsScreen({super.key, required this.matchId});

  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final match = ref.watch(matchByIdProvider(matchId));
    final team = match == null ? null : ref.watch(teamByIdProvider(match.ownTeamId));

    if (match == null || team == null) {
      return const Scaffold(
        body: Center(child: Text('Spiel nicht gefunden.')),
      );
    }

    final stats = calculateTeamStats(match, team);

    return Scaffold(
      appBar: AppBar(
        title: Text('Auswertung: ${team.name} - ${match.opponentName}'),
        actions: [
          if (match.status != MatchStatus.beendet)
            IconButton(
              tooltip: 'Zur Live-Ansicht',
              onPressed: () => Navigator.of(context).pushReplacementNamed(
                AppRoutes.liveMatch,
                arguments: match.id,
              ),
              icon: const Icon(Icons.sports_handball),
            ),
          _ExportMenu(match: match, team: team),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1000;
          final summary = _SummaryColumn(match: match, team: team, stats: stats);
          final table = _PlayerTable(match: match, team: team);

          return Padding(
            padding: const EdgeInsets.all(16),
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 380, child: summary),
                      const SizedBox(width: 16),
                      Expanded(child: table),
                    ],
                  )
                : ListView(
                    children: [
                      summary,
                      const SizedBox(height: 16),
                      table,
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class _SummaryColumn extends StatelessWidget {
  const _SummaryColumn({
    required this.match,
    required this.team,
    required this.stats,
  });

  final Match match;
  final Team team;
  final TeamStats stats;

  @override
  Widget build(BuildContext context) {
    final total = stats.total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${AppFormatters.date(match.date)} · '
                  '${match.isHome ? 'Heim' : 'Auswärts'}',
                  style: const TextStyle(
                      color: ScfColors.textSecondary, fontSize: 12.5),
                ),
                const SizedBox(height: 6),
                Text(
                  '${stats.goalsFor} : ${stats.goalsAgainst}',
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${team.name} gegen ${match.opponentName}',
                  style: const TextStyle(color: ScfColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Teamkennzahlen',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 10),
                _MetricRow('Wurfquote', AppFormatters.percent(total.shotRatio)),
                _MetricRow('Wurfquote Feld',
                    AppFormatters.percent(total.fieldShotRatio)),
                _MetricRow('7-Meter',
                    '${total.goalsSevenMeter}/${total.shotsSevenMeter}'),
                _MetricRow('Paradenquote',
                    AppFormatters.percent(total.saveRatio)),
                _MetricRow('Ballverluste', '${total.ballLosses}'),
                _MetricRow('Technikfehler', '${total.technicalErrors}'),
                _MetricRow('Zeitstrafen', '${total.twoMinutes}'),
                _MetricRow('Gelbe Karten', '${total.yellowCards}'),
                _MetricRow('Rote Karten', '${total.redCards}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Trefferzonen',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 6),
                const Text('Tore / Würfe aufs Tor je Zone',
                    style: TextStyle(
                        color: ScfColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 12),
                Center(child: _ZoneHeatmap(zones: stats.zones)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: ScfColors.textSecondary, fontSize: 13.5)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _ZoneHeatmap extends StatelessWidget {
  const _ZoneHeatmap({required this.zones});

  final Map<GoalZone, ZoneTally> zones;

  @override
  Widget build(BuildContext context) {
    Widget cell(GoalZone zone) {
      final tally = zones[zone] ?? const ZoneTally();
      final hasData = tally.total > 0;
      final color = !hasData
          ? ScfColors.surfaceRaised
          : (tally.goals > 0
              ? ScfColors.success.withValues(alpha: 0.35)
              : ScfColors.danger.withValues(alpha: 0.35));
      return Container(
        width: 56,
        height: 38,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: ScfColors.outline),
        ),
        alignment: Alignment.center,
        child: hasData
            ? Text(
                '${tally.goals}/${tally.total}',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              )
            : const SizedBox.shrink(),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            cell(GoalZone.obenLinks),
            cell(GoalZone.obenMitte),
            cell(GoalZone.obenRechts),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            cell(GoalZone.untenLinks),
            cell(GoalZone.untenMitte),
            cell(GoalZone.untenRechts),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _outer(GoalZone.linksDaneben),
            _outer(GoalZone.drueber),
            _outer(GoalZone.rechtsDaneben),
          ],
        ),
      ],
    );
  }

  Widget _outer(GoalZone zone) {
    final tally = zones[zone] ?? const ZoneTally();
    return Container(
      width: 62,
      height: 28,
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: ScfColors.surfaceRaised,
        border: Border.all(color: ScfColors.outline),
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: Text(
        tally.total > 0 ? '${tally.goals}/${tally.total}' : zone.shortLabel,
        style: const TextStyle(fontSize: 10.5, color: ScfColors.textSecondary),
      ),
    );
  }
}

extension on GoalZone {
  String get shortLabel {
    switch (this) {
      case GoalZone.linksDaneben:
        return 'links';
      case GoalZone.rechtsDaneben:
        return 'rechts';
      case GoalZone.drueber:
        return 'Latte';
      default:
        return label;
    }
  }
}

class _PlayerTable extends StatelessWidget {
  const _PlayerTable({required this.match, required this.team});

  final Match match;
  final Team team;

  @override
  Widget build(BuildContext context) {
    final players = [...team.players]
      ..sort((a, b) => a.number.compareTo(b.number));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text('Spielertabelle',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 38,
                dataRowMinHeight: 42,
                dataRowMaxHeight: 46,
                columns: const [
                  DataColumn(label: Text('#')),
                  DataColumn(label: Text('Spieler')),
                  DataColumn(label: Text('Würfe'), numeric: true),
                  DataColumn(label: Text('Tore'), numeric: true),
                  DataColumn(label: Text('Quote'), numeric: true),
                  DataColumn(label: Text('7m'), numeric: true),
                  DataColumn(label: Text('Geblockt'), numeric: true),
                  DataColumn(label: Text('Technik'), numeric: true),
                  DataColumn(label: Text('BV'), numeric: true),
                  DataColumn(label: Text('Gefoult'), numeric: true),
                  DataColumn(label: Text('7m geholt'), numeric: true),
                  DataColumn(label: Text('Duelle'), numeric: true),
                  DataColumn(label: Text('Paraden'), numeric: true),
                  DataColumn(label: Text('P-Quote'), numeric: true),
                  DataColumn(label: Text('GT'), numeric: true),
                  DataColumn(label: Text('Gelb'), numeric: true),
                  DataColumn(label: Text('2min'), numeric: true),
                  DataColumn(label: Text('Rot'), numeric: true),
                  DataColumn(label: Text('Blau'), numeric: true),
                ],
                rows: [
                  for (final player in players)
                    DataRow(cells: _cellsFor(player)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<DataCell> _cellsFor(Player player) {
    final s = statsForPlayer(match, player);
    return [
      DataCell(Text('${player.number}',
          style: const TextStyle(fontWeight: FontWeight.w800))),
      DataCell(Text(player.shortName)),
      DataCell(Text('${s.shots}')),
      DataCell(Text('${s.goals}',
          style: const TextStyle(fontWeight: FontWeight.w800))),
      DataCell(Text(AppFormatters.percent(s.shotRatio))),
      DataCell(Text('${s.goalsSevenMeter}')),
      DataCell(Text('${s.blocked}')),
      DataCell(Text('${s.technicalErrors}')),
      DataCell(Text('${s.ballLosses}')),
      DataCell(Text('${s.foulsSuffered}')),
      DataCell(Text('${s.sevenMeterWon}')),
      DataCell(Text('${s.duelsWon}')),
      DataCell(Text('${s.saves}')),
      DataCell(Text(AppFormatters.percent(s.saveRatio))),
      DataCell(Text('${s.conceded}')),
      DataCell(Text('${s.yellowCards}')),
      DataCell(Text('${s.twoMinutes}')),
      DataCell(Text('${s.redCards}')),
      DataCell(Text('${s.blueCards}')),
    ];
  }
}

class _ExportMenu extends StatelessWidget {
  const _ExportMenu({required this.match, required this.team});

  final Match match;
  final Team team;

  static final _exportService = ExportService();

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
      // Windows und Linux: Exporte im Dokumente-Ordner ablegen.
      final docs = await getApplicationDocumentsDirectory();
      final folder = Directory('${docs.path}${Platform.pathSeparator}SCF_Teamlog');
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

  String _baseName() {
    final date = AppFormatters.date(match.date).replaceAll('.', '-');
    return 'scf_${team.name}_vs_${match.opponentName}_$date'
        .replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '');
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Export',
      icon: const Icon(Icons.ios_share),
      onSelected: (value) async {
        final messenger = ScaffoldMessenger.of(context);
        switch (value) {
          case 'csv_events':
            final csv = _exportService.matchEventsCsv(match, team);
            await _deliver(context, '${_baseName()}_ereignisse.csv',
                Uint8List.fromList(utf8.encode(csv)), 'text/csv');
            break;
          case 'csv_players':
            final csv = _exportService.playerStatsCsv(match, team);
            await _deliver(context, '${_baseName()}_spieler.csv',
                Uint8List.fromList(utf8.encode(csv)), 'text/csv');
            break;
          case 'pdf':
            messenger.showSnackBar(
              const SnackBar(content: Text('PDF wird erstellt ...')),
            );
            final bytes = await _exportService.matchPdf(match, team);
            await _deliver(context, '${_baseName()}.pdf', bytes, 'application/pdf');
            break;
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'csv_events',
          child: ListTile(
            leading: Icon(Icons.table_rows_outlined),
            title: Text('CSV: Ereignisse'),
          ),
        ),
        PopupMenuItem(
          value: 'csv_players',
          child: ListTile(
            leading: Icon(Icons.people_outline),
            title: Text('CSV: Spielertabelle'),
          ),
        ),
        PopupMenuItem(
          value: 'pdf',
          child: ListTile(
            leading: Icon(Icons.picture_as_pdf_outlined),
            title: Text('PDF-Bericht'),
          ),
        ),
      ],
    );
  }
}
