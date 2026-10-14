# SCF Teamlog

Handball-Statistik-App für **SC Freising** – Android, Windows und Linux.
Live-Erfassung von Aktionen für Feldspieler und Torhüter während des Spiels:
schnell, offline, ohne Ballast. Die App ist fest auf eine Mannschaft
ausgelegt – ohne Team-Verwaltung, dafür mit Kader, Aufgebot und
Gegner-Scouting.

## Web-Version (Browser, PWA)

Neben der Flutter-App gibt es eine eigenständige **Web-App** im Ordner
`web/` – reines HTML/CSS/JavaScript, ohne Build-Schritt und ohne Abhängigkeiten.
Sie läuft in jedem modernen Browser, lässt sich auf dem Handy als App
installieren (PWA) und funktioniert danach offline.

```bash
cd web
npm start          # Server mit Datenbank + Web-App auf http://localhost:5555
npm test           # Logik-Tests (Uhr, Torwart-Mapping, Statistik, Sicherung)
```

Veröffentlichen geht mit jedem statischen Hosting (z. B. GitHub Pages, Netlify):
den Ordner `web/` ausliefern. HTTPS ist nötig, damit der Offline-Modus
(Service Worker) greift.

Funktionen der Web-Version:

- **Start** mit Saisonbilanz (Siege/Unentschieden/Niederlagen, Tore), laufendem
  Spiel, Filter und Suche in der Spielliste.
- **Kader**: anlegen, bearbeiten, löschen; Filter nach Position; Prüfung auf
  doppelte Trikotnummern; CSV-Export.
- **Live-Erfassung**: Spieluhr mit Anpfiff/Pause, ±10 s / ±1 min, exakte
  Zeitvorgabe per Klick auf die Uhr, Halbzeitwechsel, Auszeit, Spielende,
  Undo. Anzeige laufender 2-Minuten-Strafen mit Countdown. Spielfeld mit
  Wurfzonen, Tor-Raster mit Trefferzonen, Gegner-Trikotnummer frei eingeben (1–99) mit Schnellwahl der zuletzt genutzten Nummern.
  Auf dem Handy umschaltbar zwischen „Ziel & Feld“ und „Aktionen“.
  Tastatur: Leertaste Start/Pause, Z Undo, Esc abbrechen, Trikotnummer
  tippen (Ziffern wählen die Nummer), T Tor, G gehalten/Parade, B Ballverlust,
  F Fehlwurf. Bildschirm bleibt während des Spiels an (sofern unterstützt).
- **Auswertung je Spiel**: Ergebnis, Spielertabelle (sortierbar), Torzonen,
  Wurfbild Feld, Wurfbild Torwart, gegnerische Werfer, Chronik mit Löschen
  und Rückgängig. Export als CSV oder Drucken/PDF.
- **Statistik über alle Spiele** mit Detailseite je Spieler und Verlaufsdiagramm.
- **Daten**: Sicherung als JSON herunterladen und wiederherstellen, Übersichten
  als CSV, Alle-Daten-Löschen mit Bestätigung. Alle Daten bleiben im Browser
  (localStorage).

Die Web-Version ist unabhängig von der Flutter-App: Daten lassen sich dort
nicht direkt übernehmen. Zum Übertragen eine Sicherung als JSON nutzen.

## Ersteinrichtung

Das Repository enthält den kompletten Dart-/Flutter-Quellcode. Die
plattformspezifischen Ordner (`android/`, `windows/`, `linux/`) werden mit
einem Befehl von Flutter erzeugt:

```bash
flutter create --platforms=android,windows,linux --org de.scf --project-name scf_teamlog .
flutter pub get
flutter run -d linux      # oder -d windows / -d android
```

> **Hinweis:** Ohne diesen Schritt meldet Flutter
> „No Windows desktop project configured" (bzw. entsprechend für die
> anderen Plattformen) – die Plattformordner werden erst von
> `flutter create` erzeugt. Der Parameter `--project-name scf_teamlog`
> muss exakt so bleiben. Falls dabei `test/widget_test.dart` neu
> angelegt wird: vor `flutter test` wieder löschen.

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

### Server, Konten und Synchronisation

Die Web-Version braucht einen kleinen Server (`server/server.mjs`). Er liefert die App aus
und speichert Konten und den Teamstand in einer SQLite-Datenbank. Es werden keine
externen Pakete benötigt (Node.js 22 mit eingebautem `node:sqlite`).

```bash
node server/server.mjs                  # http://0.0.0.0:5555
PORT=3000 SCF_DATA_DIR=/pfad node server/server.mjs
```

- Datenbank: `server/data/scf-teamlog.db` (Standard, nicht im Git). Die Datei nie committen.
- Erster Aufruf: Ersteinrichtung. Dort legst du das erste Admin-Konto an.
- Synchronisation: Geräte senden nur Änderungen (geänderte Spiele, neue oder entfernte
  Ereignisse, Team). Empfangen wird per Long-Polling: Der Server antwortet sofort, sobald
  es etwas Neues gibt, sonst nach ca. 25 s mit einer kleinen leeren Antwort. Im Hintergrund
  (Tab nicht sichtbar) pausiert die Verbindung. Antworten werden komprimiert (gzip).
- Spieluhr: Der Server speichert die Startzeit des laufenden Abschnitts. Alle Geräte rechnen
  daraus dieselbe Zeit. Die Uhr läuft auch dann weiter, wenn niemand im Spiel ist. Das
  Halbzeitende setzt der Server selbst.
- Gleichzeitige Änderungen: Spiel-Kopf (Status, Uhr, Aufgebot) gewinnt der neuere Stand.
  Ereignisse werden zusammengeführt, eindeutige Ids verhindern Doppelungen.

**Rollen**

| Rolle | Ansehen | Bearbeiten (Spiele, Kader, Live, Daten) | Konten, Passwörter, Datenbank |
|---|---|---|---|
| Spieler | ja | nein | nein |
| Trainer | ja | ja | nein |
| Admin | ja | ja | ja (Admin-Panel) |

Die Rechte prüft der Server bei jeder Anfrage. Die Oberfläche blendet nur aus.
Ein vom Admin zurückgesetztes Passwort muss beim nächsten Login geändert werden.

**Tests:** `npm test` (Logik und Server, inkl. Rollen- und Sync-Tests).

**Hinweis Betrieb:** Der Server muss irgendwo dauerhaft laufen (eigener Rechner, VPS oder Container),
damit alle Geräte darauf zugreifen können. Die Datenbankdatei sollte regelmäßig gesichert werden
(Admin-Panel → „Datenbank-Datei laden“).

