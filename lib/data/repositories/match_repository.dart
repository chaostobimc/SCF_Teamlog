import 'package:hive/hive.dart';

import '../models/match.dart';

class MatchRepository {
  MatchRepository(this._box);

  final Box<Match> _box;

  List<Match> getAll() {
    final matches = _box.values.toList();
    matches.sort((a, b) => b.date.compareTo(a.date));
    return matches;
  }

  Match? byId(String id) => _box.get(id);

  Future<void> save(Match match) => _box.put(match.id, match);

  Future<void> delete(String id) => _box.delete(id);
}
