// Spiel anlegen / bearbeiten und Spiel-Auswertung (Overview).
import {
  clock,
  createMatch,
  dateLabel,
  dateTimeLabel,
  EVENT_TYPES,
  COURT_ZONE_LABELS,
  GOAL_ZONE_LABELS,
  fromInputDate,
  isConcededEvent,
  isOnTargetZone,
  isShotEvent,
  PHASE_LABELS,
  playerFullName,
  playerShortName,
  toInputDate,
} from '../model.js';
import {
  combineStats,
  derived,
  keeperShotMap,
  opponentShooters,
  resultOf,
  scoreOf,
  statsForPlayer,
  teamStats,
} from '../stats.js';
import { courtSvg, goalGridEl } from '../court.js';
import {
  dataTable,
  emptyState,
  homeAwayTag,
  pageHead,
  resultPill,
  statCard,
  statusPill,
} from '../components.js';
import { confirmDialog, csvPercent, downloadFile, h, openDialog, sanitizeFilename, toast, toCsv } from '../ui.js';

// ------------------------------------------------------------ Formular

/** Gemeinsames Formular fuer Neuanlage und Bearbeitung. */
export function matchForm(store, match = null) {
  const players = [...store.team.players].sort((a, b) => a.number - b.number);
  const allIds = players.map((p) => p.id);
  const initialSquad = match
    ? (match.squadPlayerIds.length ? match.squadPlayerIds : allIds)
    : allIds;
  const squad = new Set(initialSquad);

  const opponent = h('input', { class: 'input', name: 'opponent', value: match?.opponentName ?? '', placeholder: 'z. B. TSV Ottobrunn', autocomplete: 'off', required: true });
  const date = h('input', { class: 'input', type: 'date', name: 'date', value: toInputDate(match?.date ?? Date.now()) });
  const home = match ? match.isHome : true;
  const radio = (name, value, label, checked) => h('label', { class: 'seg' },
    h('input', { type: 'radio', name, value, checked }), h('span', {}, label));
  const isHomeGroup = h('div', { class: 'segmented', role: 'radiogroup', 'aria-label': 'Heim oder Auswärts' },
    radio('home', 'heim', 'Heimspiel', home),
    radio('home', 'auswaerts', 'Auswärts', !home),
  );
  const halfValues = [20, 25, 30, 35];
  const halfGroup = h('div', { class: 'segmented', role: 'radiogroup', 'aria-label': 'Halbzeitlänge' },
    halfValues.map((v) => h('label', { class: 'seg' },
      h('input', { type: 'radio', name: 'half', value: v, checked: (match?.halfLengthMin ?? 30) === v }),
      h('span', {}, `${v} min`))),
  );
  const errorBox = h('p', { class: 'form-error', role: 'alert' });

  const checkboxes = new Map();
  const toggleAll = (on) => {
    for (const [id, input] of checkboxes) {
      input.checked = on;
      if (on) squad.add(id);
      else squad.delete(id);
    }
    counter.textContent = `${squad.size}/${players.length} im Aufgebot`;
  };
  const counter = h('span', { class: 'muted small' }, `${squad.size}/${players.length} im Aufgebot`);
  const groupList = (label, list) => list.length ? h('div', { class: 'squad-group' },
    h('div', { class: 'squad-group-title' }, label, ` (${list.length})`),
    h('div', { class: 'squad-picks' }, list.map((p) => {
      const input = h('input', { type: 'checkbox', checked: squad.has(p.id) });
      checkboxes.set(p.id, input);
      input.addEventListener('change', () => {
        if (input.checked) squad.add(p.id);
        else squad.delete(p.id);
        counter.textContent = `${squad.size}/${players.length} im Aufgebot`;
      });
      return h('label', { class: `squad-pick ${p.position === 'torwart' ? 'is-keeper' : ''}` },
        input,
        h('span', { class: 'jersey-mini' }, String(p.number)),
        h('span', { class: 'squad-pick-name' }, playerShortName(p)),
      );
    })),
  ) : null;

  const node = h('div', { class: 'form-stack' },
    h('label', { class: 'field' }, h('span', {}, 'Gegner'), opponent),
    h('div', { class: 'form-grid' },
      h('label', { class: 'field' }, h('span', {}, 'Datum'), date),
      h('div', { class: 'field' }, h('span', {}, 'Spielort'), isHomeGroup),
    ),
    h('div', { class: 'field' }, h('span', {}, 'Halbzeitlänge (Uhr im Live-Spiel anpassbar)'), halfGroup),
    h('div', { class: 'field' },
      h('div', { class: 'squad-head' },
        h('span', {}, 'Aufgebot'),
        counter,
        h('span', { class: 'spacer' }),
        h('button', { type: 'button', class: 'link-btn', onclick: () => toggleAll(true) }, 'Alle'),
        h('button', { type: 'button', class: 'link-btn', onclick: () => toggleAll(false) }, 'Keine'),
      ),
      players.length === 0
        ? h('p', { class: 'muted small' }, 'Noch kein Kader angelegt – das Spiel wird ohne Aufgebot angelegt.')
        : [
            groupList('Torhüter', players.filter((p) => p.position === 'torwart')),
            groupList('Feldspieler', players.filter((p) => p.position === 'feldspieler')),
          ],
    ),
    errorBox,
  );

  return {
    node,
    read() {
      const dateValue = date.value ? fromInputDate(date.value) : Date.now();
      const isHome = node.querySelector('input[name="home"]:checked')?.value !== 'auswaerts';
      const half = Number(node.querySelector('input[name="half"]:checked')?.value ?? 30);
      const squadIds = squad.size === players.length ? [] : [...squad];
      return { opponentName: opponent.value.trim(), date: dateValue, isHome, halfLengthMin: half, squadPlayerIds: squadIds };
    },
    validate(error) {
      errorBox.textContent = error ?? '';
      if (error) opponent.focus();
      return !error;
    },
    focusFirst: () => opponent.focus(),
  };
}

// --------------------------------------------------------- Neues Spiel

export function renderSetup({ store, navigate }) {
  const form = matchForm(store, null);
  const submit = h('button', { class: 'btn primary lg', type: 'button' }, 'Spiel anlegen & live öffnen');
  const doSave = () => {
    const data = form.read();
    if (!data.opponentName) {
      form.validate('Bitte einen Gegner eingeben.');
      return;
    }
    const match = createMatch(data);
    store.saveMatch(match);
    toast('Spiel angelegt');
    navigate(`/spiel/${match.id}/live`);
  };
  submit.addEventListener('click', doSave);

  const card = h('section', { class: 'card form-card' },
    h('form', { class: 'form-stack', onsubmit: (e) => { e.preventDefault(); doSave(); } },
      form.node,
      h('div', { class: 'form-actions' },
        h('a', { class: 'btn ghost', href: '#/' }, 'Abbrechen'),
        submit,
      ),
    ),
  );
  return h('div', { class: 'page narrow' },
    pageHead({ eyebrow: 'Spieltag', title: 'Neues Spiel', subtitle: 'Gegner, Rahmen und Aufgebot festlegen. Die Uhr startest du im Live-Spiel.' }),
    store.team.players.length === 0
      ? h('div', { class: 'notice' }, 'Noch kein Kader vorhanden. ', h('a', { href: '#/kader' }, 'Jetzt Kader anlegen →'))
      : null,
    card,
  );
}

/** Dialog zum Bearbeiten von Spieldaten. */
export function editMatchDialog(store, match, onSaved) {
  const form = matchForm(store, match);
  return openDialog({
    title: 'Spiel bearbeiten',
    submitLabel: 'Speichern',
    body: form.node,
    onSubmit: () => {
      const data = form.read();
      if (!data.opponentName) {
        form.validate('Bitte einen Gegner eingeben.');
        return false;
      }
      const updated = { ...match, ...data };
      store.saveMatch(updated);
      toast('Spiel gespeichert');
      onSaved?.(updated);
      return true;
    },
  });
}

// ------------------------------------------------------------ Auswertung

export function renderOverview({ store, navigate, params }) {
  const match = store.getMatch(params[0]);
  if (!match) return { node: missingMatch() };

  const wrapper = h('div', { class: 'page-wrap' });
  const rerender = () => {
    const fresh = store.getMatch(match.id);
    if (!fresh) {
      navigate('/');
      return;
    }
    wrapper.replaceChildren(buildOverview(store, fresh, navigate, rerender));
  };
  wrapper.append(buildOverview(store, match, navigate, rerender));
  return wrapper;
}

function missingMatch() {
  return h('div', { class: 'page narrow' }, emptyState({
    icon: '?',
    title: 'Spiel nicht gefunden',
    text: 'Das Spiel existiert nicht (mehr).',
    action: h('a', { class: 'btn primary', href: '#/' }, 'Zur Startseite'),
  }));
}

function buildOverview(store, match, navigate, rerender) {
  const team = store.team;
  const stats = teamStats(match);
  const total = derived(stats.total);
  const score = scoreOf(match);
  const result = resultOf(match);
  const resultText = { sieg: 'Sieg', remis: 'Unentschieden', niederlage: 'Niederlage' }[result] ?? '';
  const played = match.events.length > 0 || match.status !== 'geplant';

  // Spieler fuer die Tabelle: Aufgebot (oder alle) plus alle mit Ereignissen
  const squadIds = match.squadPlayerIds.length ? new Set(match.squadPlayerIds) : null;
  const eventIds = new Set(match.events.map((e) => e.playerId));
  const rowPlayers = team.players
    .filter((p) => !squadIds || squadIds.has(p.id) || eventIds.has(p.id))
    .sort((a, b) => a.number - b.number);
  const rows = rowPlayers.map((p) => ({ player: p, s: statsForPlayer(match, p.id), d: null }));
  for (const r of rows) r.d = derived(r.s);

  const hero = h('section', { class: 'match-hero' },
    h('div', { class: 'match-hero-top' },
      h('div', { class: 'match-hero-meta' },
        h('span', { class: 'eyebrow' }, `${dateTimeLabel(match.date)} · ${match.halfLengthMin} min Halbzeiten`),
        h('div', { class: 'match-hero-tags' }, homeAwayTag(match), statusPill(match), resultPill(match)),
      ),
    ),
    h('div', { class: 'scoreboard' },
      h('div', { class: 'team-side' },
        h('div', { class: 'team-name' }, team.name),
        h('div', { class: 'team-tag' }, match.isHome ? 'Heim' : 'Gast')),
      h('div', { class: 'score-big' },
        played ? h('span', {}, String(score.goalsFor)) : h('span', { class: 'muted' }, '–'),
        h('span', { class: 'colon' }, ':'),
        played ? h('span', {}, String(score.goalsAgainst)) : h('span', { class: 'muted' }, '–')),
      h('div', { class: 'team-side away' },
        h('div', { class: 'team-name' }, match.opponentName || 'Gegner'),
        h('div', { class: 'team-tag' }, match.isHome ? 'Gast' : 'Heim')),
    ),
    resultText ? h('div', { class: 'match-hero-result' }, resultText) : null,
    h('div', { class: 'match-hero-actions' },
      h('a', { class: 'btn primary', href: `#/spiel/${match.id}/live` }, match.status === 'beendet' ? 'Ereignisse ansehen' : match.status === 'laufend' ? '● Live weiter' : '▶ Live starten'),
      h('button', { class: 'btn ghost', type: 'button', onclick: () => editMatchDialog(store, match, rerender) }, 'Bearbeiten'),
      h('button', { class: 'btn ghost', type: 'button', onclick: () => exportEventsCsv(match, team) }, 'CSV Ereignisse'),
      h('button', { class: 'btn ghost', type: 'button', onclick: () => exportPlayersCsv(match, team) }, 'CSV Spieler'),
      h('button', { class: 'btn ghost', type: 'button', onclick: () => window.print() }, 'PDF / Drucken'),
      h('button', { class: 'btn danger-ghost', type: 'button', onclick: async () => {
        const ok = await confirmDialog({ title: 'Spiel löschen?', message: `Das Spiel gegen ${match.opponentName || 'den Gegner'} inklusive aller Ereignisse wird endgültig gelöscht.` });
        if (!ok) return;
        store.deleteMatch(match.id);
        toast('Spiel gelöscht');
        navigate('/');
      } }, 'Löschen'),
    ),
  );

  const kpis = h('section', { class: 'kpi-grid' },
    statCard({ label: 'Feldtore', value: `${total.fieldGoals}/${total.fieldShots}`, sub: `Quote ${fmtPct(derived(stats.total).fieldShotRatio)}`, tone: 'accent' }),
    statCard({ label: '7-Meter', value: `${total.goalsSevenMeter}/${total.shotsSevenMeter}`, sub: `Quote ${fmtPct(total.sevenMeterRatio)}`, tone: 'violet' }),
    statCard({ label: 'Paraden', value: `${keeperTotal(match).saves}`, sub: `Quote ${fmtPct(keeperTotal(match).saveRatio)}`, tone: 'cyan' }),
    statCard({ label: 'Fehler', value: `${total.ballLosses + total.technicalErrors}`, sub: `${total.ballLosses} BV · ${total.technicalErrors} Technik`, tone: 'warn' }),
    statCard({ label: 'Strafen', value: `${total.sanctions}`, sub: `${total.twoMinutes} × 2 min · ${total.yellowCards} Gelb` }),
  );

  // Spielertabelle
  const tableColumns = [
    { key: 'number', label: '#', numeric: true, sort: (r) => r.player.number, render: (r) => String(r.player.number) },
    { key: 'name', label: 'Spieler', sort: (r) => playerFullName(r.player), render: (r) => h('span', { class: 'player-cell' },
      h('span', { class: `pos-dot ${r.player.position === 'torwart' ? 'keeper' : ''}` }), playerFullName(r.player)) },
    { key: 'shots', label: 'Würfe', numeric: true, sort: (r) => r.s.shots, render: (r) => String(r.s.shots) },
    { key: 'goals', label: 'Tore', numeric: true, sort: (r) => r.s.goals, render: (r) => h('strong', {}, String(r.s.goals)) },
    { key: 'quote', label: 'Quote', numeric: true, sort: (r) => r.d.shotRatio, render: (r) => fmtPct(r.d.shotRatio) },
    { key: 'seven', label: '7m', numeric: true, title: '7-Meter-Tore', sort: (r) => r.s.goalsSevenMeter, render: (r) => String(r.s.goalsSevenMeter) },
    { key: 'blocked', label: 'Block', numeric: true, title: 'Geblockt', sort: (r) => r.s.blocked, render: (r) => String(r.s.blocked) },
    { key: 'tech', label: 'Technik', numeric: true, sort: (r) => r.d.technicalErrors, render: (r) => String(r.d.technicalErrors) },
    { key: 'bv', label: 'BV', numeric: true, title: 'Ballverluste', sort: (r) => r.s.ballLosses, render: (r) => String(r.s.ballLosses) },
    { key: 'fouled', label: 'Gefoult', numeric: true, sort: (r) => r.s.foulsSuffered, render: (r) => String(r.s.foulsSuffered) },
    { key: 'sevenWon', label: '7m geh.', numeric: true, title: '7m herausgeholt', sort: (r) => r.s.sevenMeterWon, render: (r) => String(r.s.sevenMeterWon) },
    { key: 'duels', label: 'Duelle', numeric: true, sort: (r) => r.s.duelsWon, render: (r) => String(r.s.duelsWon) },
    { key: 'saves', label: 'Paraden', numeric: true, sort: (r) => r.s.saves, render: (r) => String(r.s.saves) },
    { key: 'saveQuote', label: 'P-Quote', numeric: true, sort: (r) => r.d.saveRatio, render: (r) => fmtPct(r.d.saveRatio) },
    { key: 'conceded', label: 'GT', numeric: true, title: 'Gegentore', sort: (r) => r.s.conceded, render: (r) => String(r.s.conceded) },
    { key: 'yellow', label: 'Gelb', numeric: true, sort: (r) => r.s.yellowCards, render: (r) => String(r.s.yellowCards) },
    { key: 'two', label: '2min', numeric: true, sort: (r) => r.s.twoMinutes, render: (r) => String(r.s.twoMinutes) },
    { key: 'red', label: 'Rot', numeric: true, sort: (r) => r.s.redCards, render: (r) => String(r.s.redCards) },
    { key: 'blue', label: 'Blau', numeric: true, sort: (r) => r.s.blueCards, render: (r) => String(r.s.blueCards) },
  ];
  const sumStats = combineStats(rows.map((r) => r.s));
  const sumDerived = derived(sumStats);
  const footer = [
    'Summe', '', String(sumStats.shots), String(sumStats.goals), fmtPct(sumDerived.shotRatio),
    String(sumStats.goalsSevenMeter), String(sumStats.blocked), String(sumDerived.technicalErrors),
    String(sumStats.ballLosses), String(sumStats.foulsSuffered), String(sumStats.sevenMeterWon),
    String(sumStats.duelsWon), String(sumStats.saves), fmtPct(sumDerived.saveRatio), String(sumStats.conceded),
    String(sumStats.yellowCards), String(sumStats.twoMinutes), String(sumStats.redCards), String(sumStats.blueCards),
  ];
  const playersTable = rows.length
    ? dataTable({ columns: tableColumns, rows, sortKey: 'goals', sortDir: 'desc', footer, caption: 'Spielertabelle' })
    : emptyState({ title: 'Keine Spieler im Aufgebot', text: 'Im Spiel-Bearbeiten-Dialog Spieler ins Aufgebot nehmen.' });

  // Torzonen (Schuetze): Tore/Paraden aus den Zonen-Tallies, Fehlwuerfe in Daneben-Zonen
  const zoneTallies = { ...stats.zones };
  for (const e of match.events) {
    if (e.isOpponent || !e.goalZone || isOnTargetZone(e.goalZone)) continue;
    const t = zoneTallies[e.goalZone] ?? { goals: 0, saved: 0 };
    zoneTallies[e.goalZone] = { goals: t.goals, saved: t.saved + 1 };
  }
  const zonesCard = h('section', { class: 'card' },
    h('div', { class: 'card-head' }, h('h2', {}, 'Torzonen'), h('span', { class: 'muted small' }, 'Tore / Würfe je Zone')),
    goalGridEl({ tallies: zoneTallies, mode: 'schuetze', disabled: true }),
    h('p', { class: 'muted small' }, 'Schuss ins Tor: Tore/Würfe. Daneben/Latte als Fehlwurf gezählt.'),
  );

  // Feldwurf-Heatmap
  const heat = {};
  for (const e of match.events) {
    if (e.isOpponent || !isShotEvent(e.type) || !e.courtZone || e.courtZone === 'freiwurf') continue;
    const z = e.courtZone;
    heat[z] = heat[z] ?? { value: 0, goals: 0 };
    heat[z].value += 1;
    if (e.type === 'tor') heat[z].goals += 1;
  }
  for (const z of Object.keys(heat)) heat[z].label = `${heat[z].goals}/${heat[z].value}`;
  const courtCard = h('section', { class: 'card' },
    h('div', { class: 'card-head' }, h('h2', {}, 'Wurfbild Feld'), h('span', { class: 'muted small' }, 'Wurfposition (Tore/Würfe)')),
    courtSvg({ heat: Object.keys(heat).length ? heat : null, interactive: false }),
    Object.keys(heat).length === 0 ? h('p', { class: 'muted small' }, 'Noch keine Würfe mit Wurfposition erfasst.') : null,
    h('p', { class: 'muted small' }, `7-Meter: ${total.goalsSevenMeter}/${total.shotsSevenMeter} · Freiwurf-Würfe separat in der Chronik`),
  );

  // Torwart
  const keeperCards = [];
  const keepers = team.players.filter((p) => p.position === 'torwart' && (!squadIds || squadIds.has(p.id) || eventIds.has(p.id)));
  const keeperMap = keeperShotMap(match, null);
  keeperCards.push(keeperBlock('Gesamt', keeperMap));
  for (const k of keepers) {
    const km = keeperShotMap(match, k.id);
    if (km.shotsFaced === 0) continue;
    keeperCards.push(keeperBlock(playerFullName(k), km));
  }
  const keeperSection = h('section', { class: 'card keeper-card' },
    h('div', { class: 'card-head' }, h('h2', {}, 'Wurfbild Torwart'), h('span', { class: 'muted small' }, 'Gegnerwürfe – wohin und woher')),
    keeperMap.shotsFaced === 0
      ? h('p', { class: 'muted' }, 'Noch keine Gegnerwürfe erfasst. Torhüter auswählen und Gegner-Aktionen im Live-Spiel tippen.')
      : h('div', { class: 'keeper-grid' }, keeperCards),
  );

  // Gegnerische Werfer
  const shooters = opponentShooters(match);
  const shooterRows = Object.entries(shooters)
    .map(([num, s]) => ({ number: Number(num), ...s, eff: s.onTarget ? s.conceded / s.onTarget : NaN }))
    .sort((a, b) => b.shots - a.shots || a.number - b.number);
  const shooterCard = h('section', { class: 'card' },
    h('div', { class: 'card-head' }, h('h2', {}, 'Gegnerische Werfer'), h('span', { class: 'muted small' }, 'je Trikotnummer')),
    shooterRows.length
      ? dataTable({
          columns: [
            { key: 'number', label: 'Nr.', numeric: true, render: (r) => (r.number ? String(r.number) : '–'), sort: (r) => r.number },
            { key: 'shots', label: 'Würfe', numeric: true, render: (r) => String(r.shots), sort: (r) => r.shots },
            { key: 'onTarget', label: 'aufs Tor', numeric: true, render: (r) => String(r.onTarget), sort: (r) => r.onTarget },
            { key: 'conceded', label: 'Tore', numeric: true, render: (r) => h('strong', {}, String(r.conceded)), sort: (r) => r.conceded },
            { key: 'saves', label: 'Paraden', numeric: true, render: (r) => String(r.saves), sort: (r) => r.saves },
            { key: 'misses', label: 'Fehl/Block', numeric: true, render: (r) => String(r.misses), sort: (r) => r.misses },
            { key: 'eff', label: 'Trefferquote', numeric: true, render: (r) => fmtPct(r.eff), sort: (r) => r.eff },
          ],
          rows: shooterRows,
          sortKey: 'shots',
          sortDir: 'desc',
        })
      : h('p', { class: 'muted' }, 'Noch keine Gegnerwürfe erfasst.'),
    h('p', { class: 'muted small' }, 'Nr. „–“ = Gegner ohne erfasste Trikotnummer.'),
  );

  // Chronik
  const timeline = h('section', { class: 'card' },
    h('div', { class: 'card-head' }, h('h2', {}, 'Chronik'), h('span', { class: 'muted small' }, `${match.events.length} Ereignisse`)),
    match.events.length === 0
      ? h('p', { class: 'muted' }, 'Noch keine Ereignisse erfasst.')
      : h('ol', { class: 'timeline' },
          [...match.events].reverse().map((e) => {
            const p = team.players.find((x) => x.id === e.playerId);
            const cls = e.isOpponent ? 'opp' : (isConcededEvent(e.type) ? 'bad' : (isGoodEvent(e.type) ? 'good' : ''));
            return h('li', { class: `tl-item ${cls}` },
              h('span', { class: 'tl-time' }, clock(e.matchClockSec)),
              h('span', { class: 'tl-phase muted small' }, PHASE_LABELS[e.phase] ?? ''),
              h('div', { class: 'tl-main' },
                h('div', { class: 'tl-title' },
                  e.isSevenMeter ? h('span', { class: 'tag tag-violet' }, '7m') : null,
                  h('strong', {}, EVENT_TYPES[e.type]?.label ?? e.type), ' ',
                  h('span', { class: 'muted' }, p ? `· ${playerShortName(p)} (#${p.number})` : ''),
                  e.isOpponent && e.opponentNumber ? h('span', { class: 'tag' }, `Gegner #${e.opponentNumber}`) : null,
                ),
                h('div', { class: 'tl-sub muted small' },
                  e.goalZone ? `Tor: ${GOAL_ZONE_LABELS[e.goalZone]}` : '',
                  e.goalZone && e.courtZone ? ' · ' : '',
                  e.courtZone ? `Feld: ${COURT_ZONE_LABELS[e.courtZone]}` : ''),
              ),
              h('button', { class: 'icon-btn small', type: 'button', title: 'Ereignis löschen', 'aria-label': 'Ereignis löschen', onclick: () => deleteEvent(store, match, e, rerender) }, '✕'),
            );
          })),
  );

  return h('div', { class: 'page' },
    h('nav', { class: 'breadcrumb no-print' }, h('a', { href: '#/' }, 'Start'), ' / ', h('span', {}, match.opponentName || 'Spiel')),
    hero,
    kpis,
    h('section', { class: 'card table-card' },
      h('div', { class: 'card-head' }, h('h2', {}, 'Spielertabelle'), h('span', { class: 'muted small' }, 'Spalte anklicken zum Sortieren')),
      playersTable),
    h('div', { class: 'grid-2' }, zonesCard, courtCard),
    keeperSection,
    h('div', { class: 'grid-2' }, shooterCard, timeline),
  );
}

function keeperTotal(match) {
  return keeperShotMap(match, null);
}

function keeperBlock(title, km) {
  const hasData = km.shotsFaced > 0;
  return h('div', { class: 'keeper-block' },
    h('div', { class: 'keeper-head' },
      h('strong', {}, title),
      h('span', { class: 'muted small' }, `${km.saves} Paraden · ${km.conceded} Gegentore · Quote ${fmtPct(km.saveRatio)}`)),
    hasData
      ? goalGridEl({
          tallies: Object.fromEntries(Object.entries(km.goalZones).map(([z, t]) => [z, { goals: t.goals, saved: t.saved }])),
          mode: 'torwart',
          disabled: true,
        })
      : h('p', { class: 'muted small' }, 'Keine Daten.'),
    hasData && Object.keys(km.originsOnTarget).length
      ? h('div', { class: 'origin-list' },
          h('span', { class: 'muted small' }, 'Wurfpositionen: '),
          Object.entries(km.originsOnTarget).map(([z, t]) => h('span', { class: 'tag' }, `${COURT_ZONE_LABELS[z]} ${t.saved + t.goals} (${t.goals} GT)`)))
      : null,
  );
}

function isGoodEvent(type) {
  return ['tor', 'gefoult', 'siebenMeterHerausgeholt', 'duelGewonnen', 'parade', 'paradeSiebenMeter', 'paradeFreiwurf', 'wurfGehalten'].includes(type);
}

function fmtPct(ratio) {
  if (ratio === null || Number.isNaN(ratio)) return '–';
  return `${Math.round(ratio * 100)}%`;
}

async function deleteEvent(store, match, event, rerender) {
  const fresh = store.getMatch(match.id);
  if (!fresh) return;
  const index = fresh.events.findIndex((e) => e.id === event.id);
  if (index === -1) return;
  const removed = fresh.events[index];
  store.saveMatch({ ...fresh, events: fresh.events.filter((e) => e.id !== event.id) });
  toast('Ereignis gelöscht', {
    action: {
      label: 'Rückgängig',
      onClick: () => {
        const latest = store.getMatch(match.id);
        if (!latest) return;
        const events = [...latest.events];
        events.splice(Math.min(index, events.length), 0, removed);
        store.saveMatch({ ...latest, events });
        rerender?.();
      },
    },
  });
  rerender?.();
}

// ------------------------------------------------------------- Exporte

function exportEventsCsv(match, team) {
  const rows = [['Spielzeit', 'Halbzeit', 'Spieler', 'Nummer', 'Aktion', '7m', 'Torzone', 'Feldzone', 'Gegner-Nr.']];
  for (const e of match.events) {
    const p = team.players.find((x) => x.id === e.playerId);
    rows.push([
      clock(e.matchClockSec),
      PHASE_LABELS[e.phase],
      p ? playerFullName(p) : '?',
      p?.number ?? '',
      EVENT_TYPES[e.type]?.label ?? e.type,
      e.isSevenMeter ? 'ja' : 'nein',
      e.goalZone ? GOAL_ZONE_LABELS[e.goalZone] : '',
      e.courtZone ? COURT_ZONE_LABELS[e.courtZone] : '',
      e.isOpponent ? (e.opponentNumber ?? '') : '',
    ]);
  }
  downloadFile(`${fileBase(match)}_Ereignisse.csv`, toCsv(rows), 'text/csv;charset=utf-8');
}

function exportPlayersCsv(match, team) {
  const rows = [['Nummer', 'Spieler', 'Würfe', 'Tore', 'Quote %', '7m Tore', 'Geblockt', 'Technikfehler', 'Ballverluste', 'Gefoult', '7m geholt', 'Duelle gew.', 'Paraden', 'Paradenquote %', 'Gegentore', 'Gelb', '2min', 'Rot', 'Blau']];
  for (const p of [...team.players].sort((a, b) => a.number - b.number)) {
    const s = statsForPlayer(match, p.id);
    const d = derived(s);
    rows.push([p.number, playerFullName(p), s.shots, s.goals, csvPercent(d.shotRatio), s.goalsSevenMeter, s.blocked, d.technicalErrors, s.ballLosses, s.foulsSuffered, s.sevenMeterWon, s.duelsWon, s.saves, csvPercent(d.saveRatio), s.conceded, s.yellowCards, s.twoMinutes, s.redCards, s.blueCards]);
  }
  downloadFile(`${fileBase(match)}_Spieler.csv`, toCsv(rows), 'text/csv;charset=utf-8');
}

function fileBase(match) {
  return sanitizeFilename(`SCF_${dateLabel(match.date).replace(/\./g, '-')}_${match.opponentName || 'Spiel'}`);
}
