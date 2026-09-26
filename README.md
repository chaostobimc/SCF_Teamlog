# SCF Teamlog

Handball-Statistik-App für **SC Freising** – Android, Windows und Linux.
Live-Erfassung von Aktionen für Feldspieler und Torhüter während des Spiels:
schnell, offline, ohne Ballast. Die App ist fest auf eine Mannschaft
ausgelegt – ohne Team-Verwaltung, dafür mit Kader, Aufgebot und
Gegner-Scouting.

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

- **Feste Mannschaft**: SC Freising ist die einzige Mannschaft – kein
  Anlegen von Teams. Der **Kader** (Trikotnummer, Name, Position, Rolle)
  wird direkt gepflegt.
- **Spiele anlegen**: Gegner, Datum, Heim/Auswärts, Halbzeitlänge
  (20–35 min) und **Aufgebot** – pro Spiel auswählen, welche Kaderspieler
  im Aufgebot stehen; im Live-Spiel erscheinen nur diese.
- **Live-Match-Screen** (kompakt, kaum Scrollen):
  - **Trikotnummern als vertikale Leiste am linken Bildschirmrand** –
    Tasten 1–9 am Desktop.
  - Spielfeld (Wurfposition) und Tor-Raster (Trefferzone) in der Mitte,
    Aktionen rechts – auf dem Phone über „Ziel / Aktionen" umgeschaltet.
  - Stoppuhr mit Start/Pause, automatischem Halbzeitwechsel und
    **Spielzeit-Korrektur** (±10 s / ±1 min oder exakt setzen) per Tippen
    auf die Uhr.
  - Aktionen Feldspieler: Tor, Fehlwurf, geblockt, Schrittfehler,
    Prellfehler, Stürmerfoul, Ballverlust, Gefoult, 7m herausgeholt,
    Duell gewonnen.
  - Aktionen Torhüter: Parade, Gegentor, 7m-Parade, Freiwurf-Parade.
  - **Gegnerwürfe mit Trikotnummer des Gegners**: Nummern-Leiste
    (sticky, plus Ziffernblock für zweistellige Nummern) – dadurch
    exakte Wurfbilder je Gegner-Nr.
  - Sanktionen: Gelbe Karte, 2-Minuten-Strafe, Rote/Blaue Karte.
  - Undo (Taste Z), Einzelaktionen über die Ereignisliste löschen.
  - Tastaturkürzel am Desktop (Leertaste, Z, Esc, 1–9).
- **Auswertung**: Wurfquote, Paradenquote, Ballverluste, Zeitstrafen,
  Trefferzonen-Heatmap, **Wurfbild des Torwarts** (Torzonen +
  Wurfpositionen), **Gegner-Werfertabelle je Trikotnummer**, Spielertabelle –
  live während und nach dem Spiel.
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
    database/                # Boxen, Adapter, SC-Freising-Seed
    export/                  # CSV- und PDF-Erzeugung
    models/                  # Player, Team, Match, MatchEvent (+ Hive-Adapter)
    repositories/            # Zugriff auf die Hive-Boxen
  logic/
    match_controller.dart    # Spieluhr, Phasen, Ereignisse (StateNotifier)
    match_state.dart         # Zustand des Live-Spiels
    stats_calculator.dart    # Kennzahlen je Spieler/Team/Zone/Gegner
    providers.dart           # Riverpod-Provider
  features/
    home/                    # Startübersicht mit Verlauf
    match_setup/             # Neues Spiel + Aufgebot
    live/                    # Live-Match-Screen + Widgets (Nummernleiste, Feld, Aktionen)
    stats/                   # Auswertung, Wurfbild, Gegner, Spielerstatistiken
    teams/                   # Kader-Verwaltung
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
- **Responsiv**: ab 900 px drei Spalten (Nummernleiste | Feld + Tor |
  Aktionen), darunter Phone-Layout mit umschaltbaren Reitern – optimiert für
  Touch, volle Nutzung unter Android, Windows und Linux.

## Tests

```bash
flutter test
```

Covers Modelle, Match-Controller (Uhr, Phasen, Undo, Torhüter-Mapping),
Statistik-Berechnung und die Zonen-Geometrie des Spielfelds.
