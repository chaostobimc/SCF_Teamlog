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
import '../../data/models/match_event.dart';
import '../../data/models/player.dart';
import '../../data/models/team.dart';
import '../../logic/providers.dart';
import '../../logic/stats_calculator.dart';
import '../../routing/app_router.dart';
import '../live/widgets/goal_grid.dart';

/// Auswertung eines Spiels: Uebersicht, Wurfbild, Tabelle, Export.
class MatchStatsScreen extends ConsumerStatefulWidget {
  const MatchStatsScreen({super.key, required this.matchId});

  final String matchId;

  @override
  ConsumerState<MatchStatsScreen> createState() => _MatchStatsScreenState();
}

class _MatchStatsScreenState extends ConsumerState<MatchStatsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final GlobalKey _overviewKey = GlobalKey();
  final GlobalKey _shotmapKey = GlobalKey();
  final GlobalKey _tableKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final match = ref.watch(matchByIdProvider(widget.matchId));
    final team =
        match == null ? null : ref.watch(teamByIdProvider(match.ownTeamId));

    if (match == null || team == null) {
      return const Scaffold(
        body: Center(child: Text('Spiel nicht gefunden.')),
      );
    }

    final stats = calculateTeamStats(match, team);
    final shotMap = keeperShotMap(match);

    return Scaffold(
      appBar: AppBar(
        title: Text('${team.name} – ${match.opponentName}'),
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
          _ExportMenu(
            match: match,
            team: team,
            captureOverview: () => captureWidgetPng(_overviewKey),
            captureShotmap: () => captureWidgetPng(_shotmapKey),
            captureTable: () => captureWidgetPng(_tableKey),
          ),
        ],
      ),
      body: Column(
        children: [
          Material(
            color: ScfColors.surface,
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(icon: Icon(Icons.dashboard_outlined), text: 'Übersicht'),
                Tab(icon: Icon(Icons.gps_fixed), text: 'Wurfbild'),
                Tab(icon: Icon(Icons.table_rows_outlined), text: 'Tabelle'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: RepaintBoundary(
                    key: _overviewKey,
                    child: ColoredBox(
                      color: ScfColors.background,
                      child: _OverviewTab(
                          match: match, team: team, stats: stats),
                    ),
                  ),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: RepaintBoundary(
                    key: _shotmapKey,
                    child: ColoredBox(
                      color: ScfColors.background,
                      child: _ShotmapTab(
                          match: match, team: team, shotMap: shotMap),
                    ),
                  ),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: RepaintBoundary(
                    key: _tableKey,
                    child: ColoredBox(
                      color: ScfColors.background,
                      child: _PlayerTable(match: match, team: team),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- Uebersicht

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _ScoreCard(match: match, team: team, stats: stats),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricsCard(total: total),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Torzone der eigenen Würfe',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 4),
                const Text('Tore / Würfe aufs Tor je Zone',
                    style: TextStyle(
                        color: ScfColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 14),
                Center(
                  child: GoalGrid(
                    onZoneTap: (_) {},
                    enabled: false,
                    showTallies: true,
                    zones: stats.zones,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    required this.match,
    required this.team,
    required this.stats,
  });

  final Match match;
  final Team team;
  final TeamStats stats;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${AppFormatters.date(match.date)} · '
              '${match.isHome ? 'Heimspiel' : 'Auswärtsspiel'}',
              style: ScfText.caption,
            ),
            const SizedBox(height: 10),
            Text(
              '${stats.goalsFor} : ${stats.goalsAgainst}',
              style: ScfText.numberBig.copyWith(fontSize: 42),
            ),
            const SizedBox(height: 6),
            Text(
              '${team.name} gegen ${match.opponentName}',
              style: const TextStyle(
                  color: ScfColors.textPrimary,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricsCard extends StatelessWidget {
  const _MetricsCard({required this.total});

  final PlayerStats total;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Teamkennzahlen',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 10),
            _MetricRow('Wurfquote', AppFormatters.percent(total.shotRatio)),
            _MetricRow(
                'Wurfquote Feld', AppFormatters.percent(total.fieldShotRatio)),
            _MetricRow('7-Meter',
                '${total.goalsSevenMeter}/${total.shotsSevenMeter}'),
            _MetricRow('Paradenquote', AppFormatters.percent(total.saveRatio)),
            _MetricRow('Ballverluste', '${total.ballLosses}'),
            _MetricRow('Technikfehler', '${total.technicalErrors}'),
            _MetricRow('Zeitstrafen', '${total.twoMinutes}'),
            _MetricRow('Gelbe Karten', '${total.yellowCards}'),
            _MetricRow('Rote/Blaue Karten',
                '${total.redCards + total.blueCards}'),
          ],
        ),
      ),
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
          Text(label, style: ScfText.caption),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, color: ScfColors.textPrimary)),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------- Wurfbild

class _ShotmapTab extends StatelessWidget {
  const _ShotmapTab({
    required this.match,
    required this.team,
    required this.shotMap,
  });

  final Match match;
  final Team team;
  final KeeperShotMap shotMap;

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
                const Text('Wurfbild Torwart',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 4),
                Text(
                  'Paraden / Würfe aufs Tor je Zone · '
                  '${shotMap.saves} gehalten, ${shotMap.conceded} Gegentore'
                  '${shotMap.shotsOnTarget == 0 ? '' : ' (${AppFormatters.percent(shotMap.saveRatio)})'}',
                  style: const TextStyle(
                      color: ScfColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 14),
                Center(
                  child: GoalGrid(
                    onZoneTap: (_) {},
                    enabled: false,
                    showTallies: true,
                    mode: GoalGridMode.goalkeeper,
                    zones: shotMap.goalZones,
                  ),
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
                const Text('Wurfpositionen des Gegners',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 12),
                _OriginMap(shotMap: shotMap),
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
                const Text('Torhüter',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 10),
                for (final player in team.goalkeepers)
                  _KeeperRow(player: player, match: match),
                if (team.goalkeepers.isEmpty)
                  const Text('Kein Torwart im Kader',
                      style: TextStyle(color: ScfColors.textFaint)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OriginMap extends StatelessWidget {
  const _OriginMap({required this.shotMap});

  final KeeperShotMap shotMap;

  @override
  Widget build(BuildContext context) {
    final totals = <CourtZone, int>{};
    shotMap.originsOnTarget.forEach((zone, tally) {
      totals[zone] = (totals[zone] ?? 0) + tally.total;
    });
    shotMap.originMisses.forEach((zone, count) {
      totals[zone] = (totals[zone] ?? 0) + count;
    });

    if (totals.isEmpty) {
      return const Text('Noch keine Gegnerwürfe erfasst',
          style: TextStyle(color: ScfColors.textFaint));
    }

    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxCount =
        sorted.first.value == 0 ? 1 : sorted.first.value;

    return Column(
      children: [
        for (final entry in sorted)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 110,
                  child: Text(entry.key.label,
                      style: const TextStyle(
                          fontSize: 12, color: ScfColors.textSecondary)),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: entry.value / maxCount,
                      minHeight: 12,
                      backgroundColor: ScfColors.surfaceRaised,
                      color: ScfColors.cyan,
                    ),
                  ),
                ),
                SizedBox(
                  width: 34,
                  child: Text(
                    '${entry.value}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontFeatures: [FontFeature.tabularFigures()]),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _KeeperRow extends StatelessWidget {
  const _KeeperRow({required this.player, required this.match});

  final Player player;
  final Match match;

  @override
  Widget build(BuildContext context) {
    final s = statsForPlayer(match, player);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: ScfColors.cyanSoft,
            child: Text(
              '${player.number}',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: ScfColors.cyan),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(player.fullName,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Text('${s.saves} Paraden', style: ScfText.caption),
          const SizedBox(width: 12),
          Text('${s.conceded} GT', style: ScfText.caption),
          const SizedBox(width: 12),
          SizedBox(
            width: 46,
            child: Text(
              AppFormatters.percent(s.saveRatio),
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: ScfColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------- Tabelle

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
        child: SingleChildScrollView(
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

// ------------------------------------------------------------------ Export

class _ExportMenu extends StatelessWidget {
  const _ExportMenu({
    required this.match,
    required this.team,
    required this.captureOverview,
    required this.captureShotmap,
    required this.captureTable,
  });

  final Match match;
  final Team team;
  final Future<Uint8List> Function() captureOverview;
  final Future<Uint8List> Function() captureShotmap;
  final Future<Uint8List> Function() captureTable;

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
            await _deliver(
                context, '${_baseName()}.pdf', bytes, 'application/pdf');
            break;
          case 'img_overview':
            await _captureAndDeliver(context, 'uebersicht', captureOverview);
            break;
          case 'img_shotmap':
            await _captureAndDeliver(context, 'wurfbild', captureShotmap);
            break;
          case 'img_table':
            await _captureAndDeliver(context, 'tabelle', captureTable);
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
        PopupMenuDivider(),
        PopupMenuItem(
          value: 'img_overview',
          child: ListTile(
            leading: Icon(Icons.image_outlined),
            title: Text('Bild: Übersicht'),
          ),
        ),
        PopupMenuItem(
          value: 'img_shotmap',
          child: ListTile(
            leading: Icon(Icons.gps_fixed),
            title: Text('Bild: Wurfbild'),
          ),
        ),
        PopupMenuItem(
          value: 'img_table',
          child: ListTile(
            leading: Icon(Icons.grid_on_outlined),
            title: Text('Bild: Tabelle'),
          ),
        ),
      ],
    );
  }

  Future<void> _captureAndDeliver(BuildContext context, String suffix,
      Future<Uint8List> Function() capture) async {
    try {
      final bytes = await capture();
      await _deliver(
          context, '${_baseName()}_$suffix.png', bytes, 'image/png');
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bild-Export fehlgeschlagen: $error')),
        );
      }
    }
  }
}
