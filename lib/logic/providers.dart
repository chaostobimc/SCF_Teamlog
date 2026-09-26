import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../data/database/hive_setup.dart';
import '../data/models/match.dart';
import '../data/models/team.dart';
import '../data/repositories/match_repository.dart';
import '../data/repositories/team_repository.dart';
import 'match_controller.dart';
import 'match_state.dart';

final teamRepositoryProvider = Provider<TeamRepository>((ref) {
  return TeamRepository(Hive.box<Team>(teamBoxName));
});

final matchRepositoryProvider = Provider<MatchRepository>((ref) {
  return MatchRepository(Hive.box<Match>(matchBoxName));
});

Stream<List<Team>> _watchTeams(Box<Team> box) async* {
  List<Team> snapshot() =>
      box.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  yield snapshot();
  yield* box.watch().map((_) => snapshot());
}

Stream<List<Match>> _watchMatches(Box<Match> box) async* {
  List<Match> snapshot() {
    final list = box.values.toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  yield snapshot();
  yield* box.watch().map((_) => snapshot());
}

final teamsProvider = StreamProvider<List<Team>>((ref) {
  return _watchTeams(Hive.box<Team>(teamBoxName));
});

final matchesProvider = StreamProvider<List<Match>>((ref) {
  return _watchMatches(Hive.box<Match>(matchBoxName));
});

final teamByIdProvider = Provider.family<Team?, String>((ref, id) {
  final teams = ref.watch(teamsProvider).valueOrNull ?? const <Team>[];
  for (final team in teams) {
    if (team.id == id) return team;
  }
  return ref.read(teamRepositoryProvider).byId(id);
});

final matchByIdProvider = Provider.family<Match?, String>((ref, id) {
  final matches = ref.watch(matchesProvider).valueOrNull ?? const <Match>[];
  for (final match in matches) {
    if (match.id == id) return match;
  }
  return ref.read(matchRepositoryProvider).byId(id);
});

final matchControllerProvider =
    StateNotifierProvider.family<MatchController, MatchState, String>((ref, matchId) {
  final repository = ref.watch(matchRepositoryProvider);
  final teamRepository = ref.watch(teamRepositoryProvider);
  final match = repository.byId(matchId);
  final team = match == null ? null : teamRepository.byId(match.ownTeamId);
  return MatchController(repository, match: match, team: team);
});
