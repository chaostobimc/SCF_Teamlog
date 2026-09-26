import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/utils/app_formatters.dart';
import '../models/match.dart';
import '../models/player.dart';
import '../models/team.dart';
import '../../logic/stats_calculator.dart';

/// Erzeugt CSV- und PDF-Berichte zu einem Spiel.
class ExportService {
  static const String csvSeparator = ';';

  /// Kopfzeile und Zeilen der Ereignisliste als CSV.
  String matchEventsCsv(Match match, Team team) {
    final buffer = StringBuffer();
    buffer.writeln([
      'Spielzeit',
      'Halbzeit',
      'Spieler',
      'Nummer',
      'Aktion',
      '7m',
      'Torzone',
      'Feldzone',
    ].join(csvSeparator));

    for (final event in match.events) {
      final player = team.playerById(event.playerId);
      buffer.writeln([
        AppFormatters.clock(event.matchClockSec),
        event.phase.label,
        _csv(player?.fullName ?? '?'),
        player?.number ?? '',
        _csv(event.type.label),
        event.isSevenMeter ? 'ja' : 'nein',
        _csv(event.goalZone?.label ?? ''),
        _csv(event.courtZone?.label ?? ''),
      ].join(csvSeparator));
    }
    return buffer.toString();
  }

  /// Statistik-Tabelle pro Spieler als CSV.
  String playerStatsCsv(Match match, Team team) {
    final buffer = StringBuffer();
    buffer.writeln([
      'Nummer',
      'Spieler',
      'Würfe',
      'Tore',
      'Quote %',
      '7m Tore',
      'Geblockt',
      'Technikfehler',
      'Ballverluste',
      'Gefoult',
      '7m geholt',
      'Duelle gew.',
      'Paraden',
      'Paradenquote %',
      'Gegentore',
      'Gelb',
      '2min',
      'Rot',
      'Blau',
    ].join(csvSeparator));

    for (final player in team.players) {
      final stats = statsForPlayer(match, player);
      buffer.writeln([
        player.number,
        _csv(player.fullName),
        stats.shots,
        stats.goals,
        _percent(stats.shotRatio),
        stats.goalsSevenMeter,
        stats.blocked,
        stats.technicalErrors,
        stats.ballLosses,
        stats.foulsSuffered,
        stats.sevenMeterWon,
        stats.duelsWon,
        stats.saves,
        _percent(stats.saveRatio),
        stats.conceded,
        stats.yellowCards,
        stats.twoMinutes,
        stats.redCards,
        stats.blueCards,
      ].join(csvSeparator));
    }
    return buffer.toString();
  }

  /// Alltime-Tabelle eines Spielers ueber mehrere Spiele als CSV.
  String playerMatchesCsv(List<Match> matches, Player player) {
    final buffer = StringBuffer();
    buffer.writeln([
      'Datum',
      'Gegner',
      'Würfe',
      'Tore',
      'Quote %',
      '7m Tore',
      'Geblockt',
      'Technikfehler',
      'Ballverluste',
      'Paraden',
      'Gegentore',
      'Gelb',
      '2min',
      'Rot',
      'Blau',
    ].join(csvSeparator));

    var total = const PlayerStats();
    for (final match in matches) {
      final s = statsForPlayer(match, player);
      total = PlayerStats.combine(total, s);
      buffer.writeln([
        AppFormatters.date(match.date),
        _csv(match.opponentName),
        s.shots,
        s.goals,
        _percent(s.shotRatio),
        s.goalsSevenMeter,
        s.blocked,
        s.technicalErrors,
        s.ballLosses,
        s.saves,
        s.conceded,
        s.yellowCards,
        s.twoMinutes,
        s.redCards,
        s.blueCards,
      ].join(csvSeparator));
    }
    buffer.writeln([
      '',
      'GESAMT',
      total.shots,
      total.goals,
      _percent(total.shotRatio),
      total.goalsSevenMeter,
      total.blocked,
      total.technicalErrors,
      total.ballLosses,
      total.saves,
      total.conceded,
      total.yellowCards,
      total.twoMinutes,
      total.redCards,
      total.blueCards,
    ].join(csvSeparator));
    return buffer.toString();
  }

  /// Schlichter PDF-Bericht mit Spielinfo, Ergebnis und Spielertabelle.
  Future<Uint8List> matchPdf(Match match, Team team) async {
    final pdf = pw.Document();
    final stats = calculateTeamStats(match, team);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              '${team.name} - ${match.opponentName}',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Text(
            '${AppFormatters.date(match.date)}  ·  '
            '${match.isHome ? 'Heimspiel' : 'Auswärtsspiel'}  ·  '
            '${match.halfLengthMin} min je Halbzeit',
            style: const pw.TextStyle(fontSize: 11),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Endstand: ${stats.goalsFor} : ${stats.goalsAgainst}',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 16),
          pw.Text('Spielertabelle',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          _playerTable(match, team),
          pw.SizedBox(height: 16),
          pw.Text('Ereignisse',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          _eventTable(match, team),
        ],
      ),
    );
    return pdf.save();
  }

  pw.Widget _playerTable(Match match, Team team) {
    final rows = <List<String>>[
      ['#', 'Spieler', 'Würfe', 'Tore', 'Quote', '7m', 'Geblockt',
        'Technik', 'BV', 'Paraden', 'Quote', 'GT', '2min'],
      for (final player in team.players) _playerRow(player, match),
    ];
    return _table(rows);
  }

  List<String> _playerRow(Player player, Match match) {
    final s = statsForPlayer(match, player);
    return [
      '${player.number}',
      player.fullName,
      '${s.shots}',
      '${s.goals}',
      _percent(s.shotRatio),
      '${s.goalsSevenMeter}',
      '${s.blocked}',
      '${s.technicalErrors}',
      '${s.ballLosses}',
      '${s.saves}',
      _percent(s.saveRatio),
      '${s.conceded}',
      '${s.twoMinutes}',
    ];
  }

  pw.Widget _eventTable(Match match, Team team) {
    final rows = <List<String>>[
      ['Zeit', 'Halbzeit', 'Spieler', 'Aktion', '7m', 'Zonen'],
      for (final event in match.events)
        [
          AppFormatters.clock(event.matchClockSec),
          event.phase.label,
          team.playerById(event.playerId)?.fullName ?? '?',
          event.type.label,
          event.isSevenMeter ? 'ja' : '',
          [
            if (event.goalZone != null) event.goalZone!.label,
            if (event.courtZone != null) event.courtZone!.label,
          ].join(' / '),
        ],
    ];
    return _table(rows);
  }

  pw.Widget _table(List<List<String>> rows) {
    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
      cellStyle: const pw.TextStyle(fontSize: 9),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellAlignment: pw.Alignment.centerLeft,
      data: rows,
    );
  }

  String _csv(String value) {
    if (value.contains(csvSeparator) || value.contains('"')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  String _percent(double ratio) => ratio.isNaN ? '' : (ratio * 100).round().toString();
}
