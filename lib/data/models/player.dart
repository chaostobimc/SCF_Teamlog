import 'package:hive/hive.dart';

enum PlayerPosition {
  feldspieler,
  torwart;

  String get label => this == PlayerPosition.feldspieler ? 'Feldspieler' : 'Torwart';
}

enum PlayerGameRole {
  keine,
  kreis,
  rueckraumLinks,
  rueckraumMitte,
  rueckraumRechts,
  aussenLinks,
  aussenRechts;

  String get label {
    switch (this) {
      case PlayerGameRole.keine:
        return 'Ohne feste Position';
      case PlayerGameRole.kreis:
        return 'Kreisspieler';
      case PlayerGameRole.rueckraumLinks:
        return 'Rückraum links';
      case PlayerGameRole.rueckraumMitte:
        return 'Rückraum Mitte';
      case PlayerGameRole.rueckraumRechts:
        return 'Rückraum rechts';
      case PlayerGameRole.aussenLinks:
        return 'Außen links';
      case PlayerGameRole.aussenRechts:
        return 'Außen rechts';
    }
  }
}

class Player {
  Player({
    required this.id,
    required this.number,
    required this.firstName,
    required this.lastName,
    required this.position,
    this.gameRole = PlayerGameRole.keine,
  });

  final String id;
  final int number;
  final String firstName;
  final String lastName;
  final PlayerPosition position;
  final PlayerGameRole gameRole;

  String get fullName {
    final name = '$firstName $lastName'.trim();
    return name.isEmpty ? 'Nr. $number' : name;
  }

  String get shortName {
    final first = firstName.trim();
    final last = lastName.trim();
    if (first.isEmpty && last.isEmpty) return 'Nr. $number';
    if (first.isEmpty) return last;
    if (last.isEmpty) return first;
    return '${first[0]}. $last';
  }

  Player copyWith({
    int? number,
    String? firstName,
    String? lastName,
    PlayerPosition? position,
    PlayerGameRole? gameRole,
  }) {
    return Player(
      id: id,
      number: number ?? this.number,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      position: position ?? this.position,
      gameRole: gameRole ?? this.gameRole,
    );
  }

  factory Player.fromMap(Map<dynamic, dynamic> map) {
    return Player(
      id: map['id'] as String,
      number: map['number'] as int,
      firstName: (map['firstName'] as String?) ?? '',
      lastName: (map['lastName'] as String?) ?? '',
      position: PlayerPosition.values[(map['position'] as int?) ?? 0],
      gameRole: PlayerGameRole.values[(map['gameRole'] as int?) ?? 0],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'number': number,
      'firstName': firstName,
      'lastName': lastName,
      'position': position.index,
      'gameRole': gameRole.index,
    };
  }
}

class PlayerAdapter extends TypeAdapter<Player> {
  @override
  final int typeId = 2;

  @override
  Player read(BinaryReader reader) => Player.fromMap(reader.readMap());

  @override
  void write(BinaryWriter writer, Player obj) => writer.writeMap(obj.toMap());
}
