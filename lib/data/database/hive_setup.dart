import 'package:hive_flutter/hive_flutter.dart';

import '../models/match.dart';
import '../models/match_event.dart';
import '../models/player.dart';
import '../models/team.dart';
import 'seed.dart';

const String teamBoxName = 'scf_teams';
const String matchBoxName = 'scf_matches';

/// Registriert Adapter, oeffnet die lokalen Boxen und legt den Kader an.
Future<void> openAppBoxes() async {
  Hive
    ..registerAdapter(TeamAdapter())
    ..registerAdapter(PlayerAdapter())
    ..registerAdapter(MatchAdapter())
    ..registerAdapter(MatchEventAdapter());
  await Hive.openBox<Team>(teamBoxName);
  await Hive.openBox<Match>(matchBoxName);
  await seedScfTeam(Hive.box<Team>(teamBoxName));
}
