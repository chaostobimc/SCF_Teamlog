import 'dart:math';

final Random _random = Random();

/// Kurzname fuer Ereignis-IDs: Zeitstempel plus Zufallsanteil.
String newId() {
  final ts = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final rnd = _random.nextInt(0x7FFFFFFF).toRadixString(36);
  return '$ts-$rnd';
}
