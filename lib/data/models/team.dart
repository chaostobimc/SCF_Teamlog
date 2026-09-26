import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import 'player.dart';

class Team {
  Team({
    required this.id,
    required this.name,
    required this.players,
    this.primaryColor = const Color(0xFFFF7A2F),
    this.secondaryColor = const Color(0xFF12161C),
  });

  final String id;
  final String name;
  final List<Player> players;

  /// Hauptfarbe der Trikots.
  final Color primaryColor;

  /// Zweite Trikotfarbe (z. B. Hoehle der Nummer).
  final Color secondaryColor;

  List<Player> get fieldPlayers => players
      .where((p) => p.position == PlayerPosition.feldspieler)
      .toList(growable: false);

  List<Player> get goalkeepers => players
      .where((p) => p.position == PlayerPosition.torwart)
      .toList(growable: false);

  Player? playerById(String id) {
    for (final p in players) {
      if (p.id == id) return p;
    }
    return null;
  }

  Team copyWith({
    String? name,
    List<Player>? players,
    Color? primaryColor,
    Color? secondaryColor,
  }) {
    return Team(
      id: id,
      name: name ?? this.name,
      players: players ?? this.players,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
    );
  }

  factory Team.fromMap(Map<dynamic, dynamic> map) {
    final playerMaps = (map['players'] as List?) ?? const <dynamic>[];
    return Team(
      id: map['id'] as String,
      name: map['name'] as String,
      players: playerMaps
          .map((p) => Player.fromMap(p as Map<dynamic, dynamic>))
          .toList(),
      primaryColor: Color((map['primaryColor'] as int?) ?? 0xFFFF7A2F),
      secondaryColor: Color((map['secondaryColor'] as int?) ?? 0xFF12161C),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'players': players.map((p) => p.toMap()).toList(),
      'primaryColor': primaryColor.toARGB32(),
      'secondaryColor': secondaryColor.toARGB32(),
    };
  }
}

class TeamAdapter extends TypeAdapter<Team> {
  @override
  final int typeId = 1;

  @override
  Team read(BinaryReader reader) => Team.fromMap(reader.readMap());

  @override
  void write(BinaryWriter writer, Team obj) => writer.writeMap(obj.toMap());
}
