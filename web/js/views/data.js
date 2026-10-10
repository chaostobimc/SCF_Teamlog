// Daten: Sicherung (JSON), Wiederherstellung, CSV-Uebersicht, Speicherinfo, Zuruecksetzen.
import { dateLabel, EVENT_TYPES, PHASE_LABELS, SCF_TEAM_NAME } from '../model.js';
import { resultOf, scoreOf } from '../stats.js';
import { pageHead, statCard } from '../components.js';
import { confirmDialog, csvPercent, downloadFile, h, openDialog, toast, toCsv } from '../ui.js';

export function renderData({ store, navigate }) {
  const matches = store.matchesSorted();
  const playerCount = store.team.players.length;
  const bytes = new Blob([JSON.stringify(store.exportBackup())]).size;

  const fileInput = h('input', { type: 'file', accept: 'application/json,.json', class: 'sr-only', id: 'restore-file' });
  fileInput.addEventListener('change', async () => {
    const file = fileInput.files?.[0];
    fileInput.value = '';
    if (!file) return;
    let backup;
    try {
      backup = JSON.parse(await file.text());
    } catch {
      toast('Die Datei ist kein gültiges JSON.');
      return;
    }
    const count = Array.isArray(backup?.matches) ? backup.matches.length : 0;
    const ok = await confirmDialog({
      title: 'Sicherung wiederherstellen?',
      message: `Die aktuellen Daten (${matches.length} Spiele, ${playerCount} Spieler) werden durch die Sicherung ersetzt (${count} Spiele). Das lässt sich nicht rückgängig machen.`,
      confirmLabel: 'Wiederherstellen',
      danger: true,
    });
    if (!ok) return;
    try {
      store.importBackup(backup);
      toast('Sicherung wiederhergestellt');
      navigate('/daten');
    } catch (error) {
      toast(error.message);
    }
  });

  const backupBtn = h('button', {
    class: 'btn primary', type: 'button', onclick: () => {
      const date = new Date().toISOString().slice(0, 10);
      downloadFile(`SCF_Teamlog_Sicherung_${date}.json`, JSON.stringify(store.exportBackup(), null, 2), 'application/json');
      toast('Sicherung heruntergeladen');
    },
  }, 'Sicherung herunterladen');

  const restoreBtn = h('button', { class: 'btn ghost', type: 'button', onclick: () => fileInput.click() }, 'Sicherung wiederherstellen …');

  const csvBtn = h('button', {
    class: 'btn ghost', type: 'button', onclick: () => {
      const rows = [['Datum', 'Gegner', 'Heim/Auswärts', 'Status', 'Ergebnis', 'Ergebnis-Art', 'Tore', 'Gegentore', 'Würfe', 'Wurfquote', 'Ereignisse']];
      for (const m of [...matches].reverse()) {
        const s = scoreOf(m);
        const shots = m.events.filter((e) => !e.isOpponent && ['tor', 'fehlwurf', 'wurfGehalten', 'wurfGeblockt'].includes(e.type));
        const goals = shots.filter((e) => e.type === 'tor').length;
        const r = resultOf(m);
        rows.push([
          dateLabel(m.date),
          m.opponentName,
          m.isHome ? 'Heim' : 'Auswärts',
          { geplant: 'Geplant', laufend: 'Läuft', beendet: 'Beendet' }[m.status],
          `${s.goalsFor}:${s.goalsAgainst}`,
          { sieg: 'Sieg', remis: 'Unentschieden', niederlage: 'Niederlage' }[r] ?? '',
          s.goalsFor,
          s.goalsAgainst,
          shots.length,
          shots.length ? csvPercent(goals / shots.length) : '',
          m.events.length,
        ]);
      }
      downloadFile('SCF_Spiele_Uebersicht.csv', toCsv(rows), 'text/csv;charset=utf-8');
    },
  }, 'Spiele-Übersicht (CSV)');

  const journalBtn = h('button', {
    class: 'btn ghost', type: 'button', onclick: () => {
      const rows = [['Spiel', 'Datum', 'Spielzeit', 'Halbzeit', 'Spieler', 'Nummer', 'Aktion', '7m', 'Torzone', 'Feldzone']];
      for (const m of matches) {
        for (const e of m.events) {
          const p = store.team.players.find((x) => x.id === e.playerId);
          rows.push([m.opponentName, dateLabel(m.date), `${Math.floor(e.matchClockSec / 60)}:${String(e.matchClockSec % 60).padStart(2, '0')}`, PHASE_LABELS[e.phase], p ? `${p.firstName} ${p.lastName}`.trim() : '?', p?.number ?? '', EVENT_TYPES[e.type]?.label ?? e.type, e.isSevenMeter ? 'ja' : 'nein', e.goalZone ?? '', e.courtZone ?? '']);
        }
      }
      downloadFile('SCF_Alle_Ereignisse.csv', toCsv(rows), 'text/csv;charset=utf-8');
    },
  }, 'Alle Ereignisse (CSV)');

  const resetBtn = h('button', {
    class: 'btn danger', type: 'button', onclick: () => {
      openDialog({
        title: 'Alle Daten löschen?',
        submitLabel: 'Endgültig löschen',
        danger: true,
        body: h('div', { class: 'form-stack' },
          h('p', { class: 'muted' }, `Alle ${matches.length} Spiele und ${playerCount} Kaderspieler werden von diesem Gerät entfernt. Vorher unbedingt eine Sicherung laden.`),
          h('label', { class: 'field' }, h('span', {}, 'Zur Bestätigung „LÖSCHEN“ eingeben'), h('input', { class: 'input', name: 'confirm', autocomplete: 'off' })),
        ),
        onSubmit: (form) => {
          if (form.querySelector('input[name="confirm"]').value.trim() !== 'LÖSCHEN') return false;
          store.resetAll();
          toast('Alle Daten gelöscht');
          navigate('/');
          return true;
        },
      });
    },
  }, 'Alle Daten löschen');

  return h('div', { class: 'page narrow' },
    pageHead({
      eyebrow: 'Datenhaltung',
      title: 'Daten & Sicherung',
      subtitle: 'Alles wird lokal in diesem Browser gespeichert. Lade regelmäßig eine Sicherung herunter – so bist du auf der sicheren Seite und kannst Daten auf ein anderes Gerät übertragen.',
    }),
    h('section', { class: 'kpi-grid compact' },
      statCard({ label: 'Spiele', value: matches.length, icon: '🏟' }),
      statCard({ label: 'Kader', value: playerCount, tone: 'cyan', icon: '👥' }),
      statCard({ label: 'Speicher', value: `${Math.max(1, Math.round(bytes / 1024))} KB`, sub: 'lokal im Browser', tone: 'violet', icon: '💾' }),
    ),
    h('section', { class: 'card' },
      h('div', { class: 'card-head' }, h('h2', {}, 'Sicherung')),
      h('p', { class: 'muted' }, `Komplette Sicherung von ${SCF_TEAM_NAME}: Kader, alle Spiele und alle Ereignisse als JSON-Datei.`),
      h('div', { class: 'btn-row' }, backupBtn, restoreBtn, fileInput),
    ),
    h('section', { class: 'card' },
      h('div', { class: 'card-head' }, h('h2', {}, 'Export')),
      h('p', { class: 'muted' }, 'Für Excel, Google Sheets oder den Vereinsbericht. Trennzeichen Semikolon, Dateien mit UTF-8.'),
      h('div', { class: 'btn-row' }, csvBtn, journalBtn),
      h('p', { class: 'muted small' }, 'Einzelne Spiele exportierst du in der Auswertung (CSV, Drucken/PDF).'),
    ),
    h('section', { class: 'card danger-zone' },
      h('div', { class: 'card-head' }, h('h2', {}, 'Gefahrenzone')),
      h('p', { class: 'muted' }, 'Löscht alle Spiele und den Kader auf diesem Gerät.'),
      h('div', { class: 'btn-row' }, resetBtn),
    ),
  );
}
