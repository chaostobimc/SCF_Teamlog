import 'package:hive_flutter/hive_flutter.dart';

import '../models/match.dart';
import '../models/match_event.dart';
import '../models/player.dart';
import '../models/team.dart';

const String teamBoxName = 'scf_teams';
const String matchBoxName = 'scf_matches';

/// Registriert Adapter und oeffnet die lokalen Boxen.
Future<void> openAppBoxes() async {
  Hive
    ..registerAdapter(TeamAdapter())
    ..registerAdapter(PlayerAdapter())
    ..registerAdapter(MatchAdapter())
    ..registerAdapter(MatchEventAdapter());
  await Hive.openBox<Team>(teamBoxName);
  await Hive.openBox<Match>(matchBoxName);
}
