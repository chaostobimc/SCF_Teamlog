import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scf_teamlog/data/models/match_event.dart';
import 'package:scf_teamlog/features/live/widgets/handball_court.dart';

void main() {
  const size = Size(400, 276);

  test('Zonen-Geometrie: Torraum, 7m, Rueckraum und Aussen', () {
    // Direkt vor dem Tor (oben Mitte, nah am Zentrum): Kreis.
    expect(HandballCourt.zoneAt(const Offset(200, 40), size), CourtZone.kreis);

    // 7-Meter-Marke.
    final sevenPoint = Offset(size.width / 2, 8 + 276 * 0.52 + (276 * 0.95 - 276 * 0.52) * 0.28);
    expect(HandballCourt.zoneAt(sevenPoint, size), CourtZone.siebenMeter);

    // Mittlere Distanz geradeaus: Rueckraum Mitte.
    expect(HandballCourt.zoneAt(const Offset(200, 230), size), CourtZone.rueckraumMitte);

    // Schraeg links: Rueckraum links.
    expect(HandballCourt.zoneAt(const Offset(110, 160), size), CourtZone.rueckraumLinks);

    // Schraeg rechts: Rueckraum rechts.
    expect(HandballCourt.zoneAt(const Offset(290, 160), size), CourtZone.rueckraumRechts);

    // Ganz links am Fluegel: Aussen links.
    expect(HandballCourt.zoneAt(const Offset(15, 80), size), CourtZone.aussenLinks);

    // Ganz rechts am Fluegel: Aussen rechts.
    expect(HandballCourt.zoneAt(const Offset(385, 80), size), CourtZone.aussenRechts);

    // Hinter der Torlinie (oben): keine Zone.
    expect(HandballCourt.zoneAt(const Offset(200, -10), size), isNull);
  });
}
