import 'package:hive/hive.dart';

import '../models/team.dart';

class TeamRepository {
  TeamRepository(this._box);

  final Box<Team> _box;

  List<Team> getAll() => _box.values.toList();

  Team? byId(String id) => _box.get(id);

  Future<void> save(Team team) => _box.put(team.id, team);

  Future<void> delete(String id) => _box.delete(id);
}
