# SCF Teamlog

Handball-Statistik-App für Android, Windows und Linux. Live-Erfassung von
Aktionen für Feldspieler und Torhüter während des Spiels – schnell, offline,
ohne Ballast.

## Ersteinrichtung

Das Repository enthält den kompletten Dart-/Flutter-Quellcode. Die
plattformspezifischen Ordner (`android/`, `windows/`, `linux/`) werden mit
einem Befehl von Flutter erzeugt:

```bash
flutter create --platforms=android,windows,linux --org de.scf --project-name scf_teamlog .
flutter pub get
flutter run -d linux      # oder -d windows / -d android
```

Zum Bauen:

```bash
flutter build apk          # Android
flutter build windows      # Windows (unter Windows)
flutter build linux        # Linux (unter Linux)
```

## Funktionen

- **Teams & Kader**: Teams mit Trikotfarben, Spielernummern, Namen,
  Positionen (Feldspieler/Torwart) und Rollen (Kreis, Rückraum, Außen).
- **Spiele anlegen**: Gegner, Datum, Heim/Auswärts, Halbzeitlänge.
- **Live-Match-Screen**:
  - Stoppuhr mit Start/Pause, automatischem Halbzeitwechsel, Auszeit-Button,
    Zeitstempel je Aktion.
  - Laufende 2-Minuten-Strafen als Countdown-Chips.
  - Spielerleiste mit Trikotnummern zur Schnellauswahl (Tasten 1–9 am Desktop).
  - Interaktives Spielfeld: antippen der Wurfzone (Außen, Rückraum, Kreis, 7 m).
  - Tor-Raster: Trefferzone antippen, Ergebnis (Tor/Parade/Gehalten/Geblockt)
    oder automatischer Fehlwurf bei "Daneben".
  - Aktionen Feldspieler: Tor, Fehlwurf, geblockter Wurf, Schrittfehler,
    Prellfehler, Stürmerfoul, Ballverlust, Gefoult, 7m herausgeholt,
    Duell gewonnen.
  - Aktionen Torhüter: Parade, Gegentor, 7m-Parade, Freiwurf gehalten.
  - **Gegnerwürfe** für das Wurfbild des Torwarts: Zone im Tor, Wurfposition,
    Ergebnis (Parade/Gegentor) plus "Gegner daneben/geblockt".
  - Sanktionen: Gelbe Karte, 2-Minuten-Strafe, Rote/Blaue Karte.
  - Undo (Taste Z), Einzelaktionen per Tippen auf die Ereignisliste löschen.
  - Tastaturkürzel am Desktop (Leertaste, Z, Esc, 1–9).
- **Auswertung**: Wurfquote, Paradenquote, Ballverluste, Zeitstrafen,
  Trefferzonen-Heatmap, **Wurfbild des Torwarts** (Torzonen + Wurfpositionen
  des Gegners), Spielertabelle – live während und nach dem Spiel.
- **Spielerstatistiken**: pro Spiel **oder alltime** mit Aufschlüsselung
  je Begegnung.
- **Export**: CSV (Ereignisse, Spielertabelle, Spieler-Alltime) und
  PDF-Bericht – dazu **Bildexport (PNG)** von Übersicht, Wurfbild und Tabelle.
  Auf Android über den System-Dialog, unter Windows/Linux als Datei im Ordner
  `Dokumente/SCF_Teamlog`.
- **Offline-First**: alle Daten lokal in Hive, keine Internetverbindung nötig.

## Projektstruktur

```
lib/
  main.dart                  # Einstieg, Hive-Init
  app.dart                   # MaterialApp, Theme, Routing
  core/
    constants/               # Breakpoints
    theme/                   # Farben und Theme
    utils/                   # IDs, Zeit-/Zahlenformate
  data/
    database/hive_setup.dart # Boxen & Adapter
    export/                  # CSV- und PDF-Erzeugung
    models/                  # Player, Team, Match, MatchEvent (+ Hive-Adapter)
    repositories/            # Zugriff auf die Hive-Boxen
  logic/
    match_controller.dart    # Spieluhr, Phasen, Ereignisse (StateNotifier)
    match_state.dart         # Zustand des Live-Spiels
    stats_calculator.dart    # Kennzahlen je Spieler/Team/Zone
    providers.dart           # Riverpod-Provider
  features/
    home/                    # Startübersicht
    match_setup/             # Neues Spiel anlegen
    live/                    # Live-Match-Screen + Widgets
    stats/                   # Auswertung, Wurfbild, Spielerstatistiken
    teams/                   # Teamliste & Teameditor
  routing/                   # Routen
test/                        # Unit-Tests (Modelle, Logik, Geometrie)
```

## Konzept

- **State Management**: Riverpod – UI rendert den Zustand, die Logik steckt in
  `MatchController` und `stats_calculator`.
- **Datenhaltung**: Hive mit handgeschriebenen Adaptern (kein build_runner),
  serialisiert als Maps über die `toMap`/`fromMap`-Methoden der Modelle.
- **Live-Eingabe in zwei Tipps**: Spieler antippen, dann Aktion bzw. Torzone.
  Der Wurfkontext (Feldwurf / 7 m / Freiwurf) lässt sich setzen, ohne das
  Spielfeld verlassen zu müssen.
- **Responsiv**: ab 1100 px drei Spalten (Spieler | Feld | Aktionen),
  ab 640 px zwei Spalten, darunter gestapelte Touch-Optimierung.

## Tests

```bash
flutter test
```

Covers Modelle, Match-Controller (Uhr, Phasen, Undo, Torhüter-Mapping),
Statistik-Berechnung und die Zonen-Geometrie des Spielfelds.
