// Live-Ansicht: Spieluhr, Spielerleiste, Spielfeld, Tor-Raster, Aktionspanel, Chronik.
import { LiveSession } from '../match.js';
import {
  clock,
  COURT_ZONE_LABELS,
  EVENT_TYPES,
  GOAL_ZONE_LABELS,
  isShotEvent,
  PHASE_LABELS,
  playerFullName,
  playerShortName,
} from '../model.js';
import { activePenalties, keeperShotMap, scoreOf, statsForPlayer } from '../stats.js';
import { courtSvg, goalGridEl } from '../court.js';
import { emptyState, statusPill } from '../components.js';
import { h, openDialog, setChildren, toast } from '../ui.js';

const QUICK_FIELD = [
  ['tor', 'Tor', '', 'good'],
  ['fehlwurf', 'Fehlwurf', '', 'warn'],
  ['wurfGeblockt', 'Geblockt', '', 'warn'],
  ['ballverlust', 'Ballverlust', '', 'bad'],
  ['schrittfehler', 'Schritt', '', 'warn'],
  ['prellfehler', 'Prellen', '', 'warn'],
  ['gefoult', 'Gefoult', '', 'cyan'],
  ['siebenMeterHerausgeholt', '7m geholt', '', 'good'],
  ['duelGewonnen', 'Duell gew.', '', 'violet'],
  ['stuermerfoul', 'Stürmerfoul', '', 'warn'],
  ['gelbeKarte', 'Gelb', '', 'warn'],
  ['zeitstrafe', '2 min', '', 'warn'],
  ['roteKarte', 'Rot', '', 'bad'],
  ['blaueKarte', 'Blau', '', 'cyan'],
];

const QUICK_KEEPER_OPP = [
  ['fehlwurf', 'Fehlwurf', '', 'cyan'],
  ['wurfGeblockt', 'Block', '', 'cyan'],
];

const SQUAD_NUMBER_TIMEOUT = 600;

export function renderLive({ store, navigate, params }) {
  const matchId = params[0];
  const existing = store.getMatch(matchId);
  if (!existing) {
    return { node: emptyState({ icon: '?', title: 'Spiel nicht gefunden', action: h('a', { class: 'btn primary', href: '#/' }, 'Zur Startseite') }) };
  }

  let ready = false;
  let lastStamp = 0;
  let digitBuffer = '';
  let digitTimer = null;
  let wakeLock = null;
  let disposed = false;

  const session = new LiveSession({
    store,
    matchId,
    onChange: () => { if (ready) paintAll(); },
    onTick: () => { if (ready) paintClock(); },
  });

  // ------------------------------------------------------------ DOM-Gerust
  const clockEl = h('button', { class: 'clock-face', type: 'button', title: 'Spielzeit setzen', onclick: openClockDialog },
    h('span', { class: 'clock-digits' }, '00:00'));
  const phaseEl = h('span', { class: 'phase-label' });
  const statusHost = h('span', { class: 'status-host' });
  const scoreHome = h('span', { class: 'score-num' }, '0');
  const scoreAway = h('span', { class: 'score-num' }, '0');
  const titleEl = h('h1', { class: 'sr-only' }, 'Live');
  const penaltyBar = h('div', { class: 'penalty-bar', role: 'status', 'aria-live': 'polite' });
  const playBtn = h('button', { class: 'btn primary xl play-btn', type: 'button', onclick: () => session.toggleClock() });
  const hdrBtns = h('div', { class: 'clock-controls' },
    h('button', { class: 'btn ghost', type: 'button', title: '10 s zurück', onclick: () => session.adjustClock(-10) }, '−10 s'),
    playBtn,
    h('button', { class: 'btn ghost', type: 'button', title: '10 s vor', onclick: () => session.adjustClock(10) }, '+10 s'),
    h('button', { class: 'btn ghost', type: 'button', title: '1 min zurück', onclick: () => session.adjustClock(-60) }, '−1 min'),
    h('button', { class: 'btn ghost', type: 'button', title: '1 min vor', onclick: () => session.adjustClock(60) }, '+1 min'),
  );
  const phaseBtns = h('div', { class: 'phase-controls' },
    h('button', { class: 'btn ghost', type: 'button', onclick: () => session.timeout() }, '⏸ Auszeit'),
    h('button', { class: 'btn ghost', type: 'button', onclick: () => session.startSecondHalf() }, '2. Halbzeit'),
    h('button', { class: 'btn ghost', type: 'button', onclick: () => session.undoLastEvent(), title: 'Letzte Aktion rückgängig (Z)' }, '↶ Undo'),
    h('button', { class: 'btn danger-ghost', type: 'button', onclick: finishWithConfirm }, 'Beenden'),
  );
  const tabs = h('div', { class: 'live-tabs', role: 'tablist' },
    h('button', { class: 'tab is-active', type: 'button', role: 'tab', dataset: { tab: 'ziel' }, onclick: () => setTab('ziel') }, 'Ziel & Feld'),
    h('button', { class: 'tab', type: 'button', role: 'tab', dataset: { tab: 'aktion' }, onclick: () => setTab('aktion') }, 'Aktionen'),
  );
  const railEl = h('aside', { class: 'live-rail', 'aria-label': 'Kader im Spiel' });
  const courtHost = h('div', { class: 'court-host' });
  const goalHost = h('div', { class: 'goal-host' });
  const zoneHint = h('div', { class: 'zone-hint' });
  const actionHost = h('div', { class: 'action-host' });
  const timelineHost = h('div', { class: 'timeline-host' });
  const lockOverlay = h('div', { class: 'lock-overlay hidden' });
  const footHint = h('p', { class: 'hint-line' },
    'Leertaste Start/Pause · Z Rückgängig · Esc Abbrechen · Nummer tippen (z. B. 1 + 2 = #12) · T Tor · G gehalten/Parade · B Ballverlust · F Fehlwurf');

  const top = h('header', { class: 'live-top' },
    h('div', { class: 'live-top-main' },
      h('div', { class: 'live-match' },
        h('div', { class: 'live-team' }, h('span', { class: 'live-team-name' }, 'SC Freising'), scoreHome),
        h('span', { class: 'live-colon' }, ':'),
        h('div', { class: 'live-team away' }, scoreAway, h('span', { class: 'live-team-name' }, existing.opponentName || 'Gegner')),
      ),
      h('div', { class: 'live-clock' }, clockEl, h('div', { class: 'phase-row' }, phaseEl, statusHost)),
      hdrBtns,
    ),
    h('div', { class: 'live-top-sub' }, penaltyBar, phaseBtns, tabs),
  );

  const center = h('section', { class: 'live-center', 'aria-label': 'Spielfeld und Tor' },
    h('div', { class: 'panel-title' }, h('span', {}, 'Wurfposition'), zoneHint),
    courtHost,
    h('div', { class: 'panel-title' }, h('span', {}, 'Trefferzone im Tor')),
    goalHost,
  );
  const side = h('section', { class: 'live-side', 'aria-label': 'Aktionen' },
    h('div', { class: 'action-wrap' }, actionHost, lockOverlay),
    h('div', { class: 'timeline-wrap' }, h('div', { class: 'panel-title' }, h('span', {}, 'Letzte Aktionen')), timelineHost),
  );

  const root = h('div', { class: 'live', dataset: { tab: 'ziel' } },
    top,
    h('div', { class: 'live-body' }, railEl, center, side),
    footHint,
  );

  function setTab(tab) {
    root.dataset.tab = tab;
    for (const t of tabs.querySelectorAll('.tab')) {
      const on = t.dataset.tab === tab;
      t.classList.toggle('is-active', on);
      t.setAttribute('aria-selected', String(on));
    }
  }

  // ------------------------------------------------------------ Malen
  function paintClock() {
    const m = session.match;
    const phaseSec = phaseSeconds(m);
    clockEl.querySelector('.clock-digits').textContent = clock(phaseSec);
    phaseEl.textContent = PHASE_LABELS[m.phase] ?? '';
    statusHost.replaceChildren(statusPill(m));
    const running = session.running;
    playBtn.textContent = running ? '⏸ Pause' : (m.status === 'laufend' ? '▶ Weiter' : '▶ Anpfiff');
    playBtn.classList.toggle('is-running', running);
    const finished = m.status === 'beendet';
    playBtn.disabled = finished;
    root.classList.toggle('is-running', running);
    paintScore();
    paintPenalties();
  }

  function paintScore() {
    const s = scoreOf(session.match);
    scoreHome.textContent = String(s.goalsFor);
    scoreAway.textContent = String(s.goalsAgainst);
  }

  function paintPenalties() {
    const list = activePenalties(session.match);
    penaltyBar.replaceChildren(...list.map((p) => {
      const who = session.team.players.find((x) => x.id === p.event.playerId);
      return h('span', { class: 'penalty-chip' },
        h('strong', {}, `${who ? '#' + who.number : '?'} 2′`),
        h('span', { class: 'penalty-time' }, clock(p.remainingSec)));
    }));
  }

  function paintAll() {
    const m = session.match;
    paintClock();
    paintRail();
    paintCourt();
    paintGoal();
    paintAction();
    paintTimeline();
    lockOverlay.classList.toggle('hidden', session.canRecord);
    lockOverlay.replaceChildren(h('div', { class: 'lock-text' },
      h('strong', {}, m.status === 'beendet' ? 'Spiel beendet' : 'Anpfiff ausstehend'),
      h('span', { class: 'muted small' }, m.status === 'beendet'
        ? 'Ereignisse sind nur noch lesbar.'
        : 'Mit „▶ Anpfiff“ startet die Uhr und die Erfassung.')));
    if (session.notice && session.noticeStamp !== lastStamp) {
      lastStamp = session.noticeStamp;
      toast(session.notice);
    }
    if (m.status === 'beendet' && !root.querySelector('.finished-note')) {
      root.append(h('div', { class: 'finished-note' }, 'Spiel beendet. ',
        h('a', { href: `#/spiel/${m.id}` }, 'Zur Auswertung →')));
    }
    updateWakeLock();
  }

  function paintRail() {
    const players = session.squadPlayers();
    const selectedId = session.selectedPlayerId;
    const matchNow = session.match;
    const penalties = activePenalties(matchNow);
    const mins = penalties.reduce((acc, p) => { acc[p.event.playerId] = p.remainingSec; return acc; }, {});
    const cards = players.map((p, idx) => {
      const s = statsForPlayer(matchNow, p.id);
      const isKeeper = p.position === 'torwart';
      const summary = isKeeper
        ? `${s.saves} P · ${s.conceded} GT`
        : `${s.goals}/${s.shots} Tore`;
      const sel = selectedId === p.id;
      return h('button', {
        type: 'button',
        class: `rail-player ${isKeeper ? 'is-keeper' : ''} ${sel ? 'is-selected' : ''}`,
        onclick: () => session.selectPlayer(p.id),
        attrs: { 'aria-pressed': String(sel), title: `${playerFullName(p)} (#${p.number})` },
      },
        h('span', { class: 'rail-number' }, String(p.number)),
        h('span', { class: 'rail-text' },
          h('span', { class: 'rail-name' }, playerShortName(p)),
          h('span', { class: 'rail-sum' }, summary)),
        mins[p.id] !== undefined ? h('span', { class: 'rail-penalty' }, clock(mins[p.id])) : null,
        idx < 9 ? h('span', { class: 'rail-key' }, String(idx + 1)) : null,
      );
    });
    setChildren(railEl,
      h('div', { class: 'rail-head' }, h('span', {}, 'Kader'), h('span', { class: 'muted small' }, `${players.length}`)),
      players.length === 0
        ? h('p', { class: 'muted small rail-empty' }, 'Kein Aufgebot. Im Spiel unter „Bearbeiten“ Spieler auswählen.')
        : cards,
    );
  }

  function currentShotMarkers() {
    const m = session.match;
    const p = session.selectedPlayer;
    const markers = [];
    if (p?.position === 'torwart') {
      for (const e of m.events) {
        if (!e.isOpponent || e.playerId !== p.id || !e.courtZone) continue;
        markers.push({ id: e.id, zone: e.courtZone, kind: markerKind(e.type) });
      }
    } else {
      for (const e of m.events) {
        if (e.isOpponent || !isShotEvent(e.type) || !e.courtZone) continue;
        if (p && e.playerId !== p.id) continue;
        markers.push({ id: e.id, zone: e.courtZone, kind: markerKind(e.type) });
      }
    }
    return markers;
  }

  function paintCourt() {
    const selected = session.pendingShot?.courtZone ?? session.lastCourtZone ?? null;
    const court = courtSvg({
      selected,
      markers: currentShotMarkers(),
      interactive: session.canRecord,
      onZone: (zone) => session.onCourtZoneTap(zone),
    });
    courtHost.replaceChildren(court);
    const ctx = session.lastCourtZone;
    setChildren(zoneHint,
      ctx ? h('span', { class: 'tag tag-orange' }, `Zone: ${COURT_ZONE_LABELS[ctx]}`) : h('span', { class: 'muted small' }, 'keine Zone gewählt'),
      ctx ? h('button', { class: 'link-btn', type: 'button', onclick: () => session.setQuickContext(null) }, '×') : null,
    );
  }

  function paintGoal() {
    const p = session.selectedPlayer;
    const m = session.match;
    let tallies;
    let mode = 'schuetze';
    if (p?.position === 'torwart') {
      mode = 'torwart';
      const km = keeperShotMap(m, p.id);
      tallies = Object.fromEntries(Object.entries(km.goalZones).map(([z, t]) => [z, { goals: t.goals, saved: t.saved }]));
    } else {
      tallies = {};
      for (const e of m.events) {
        if (e.isOpponent || !e.goalZone) continue;
        if (p && e.playerId !== p.id) continue;
        const t = tallies[e.goalZone] ?? { goals: 0, saved: 0 };
        if (e.type === 'tor') t.goals += 1;
        else t.saved += 1;
        tallies[e.goalZone] = t;
      }
    }
    const grid = goalGridEl({
      selected: session.pendingShot?.goalZone ?? null,
      tallies,
      mode,
      disabled: !session.canRecord,
      onZone: (zone) => session.onGoalZoneTap(zone),
    });
    goalHost.replaceChildren(grid);
  }

  function paintAction() {
    const p = session.selectedPlayer;
    const isKeeper = p?.position === 'torwart';
    const pending = session.pendingShot;
    const children = [];

    // Banner
    let label;
    let tone = 'neutral';
    if (pending) { label = 'Wurf aufs Tor – Ergebnis tippen'; tone = 'good'; }
    else if (!p) { label = 'Trikotnummer links wählen – dann Aktion tippen'; }
    else if (isKeeper) {
      label = session.opponentNumber ? `Torwart ${playerShortName(p)} – Gegner #${session.opponentNumber}` : `Torwart ${playerShortName(p)} – Gegner-Aktion erfassen`;
      tone = 'cyan';
    } else { label = `Aktion für ${playerShortName(p)} (#${p.number})`; tone = 'orange'; }
    children.push(h('div', { class: `banner tone-${tone}` },
      h('span', { class: 'banner-dot' }),
      h('span', { class: 'banner-text' }, label),
      pending ? h('button', { class: 'link-btn', type: 'button', onclick: () => session.cancelPendingShot() }, 'Storno') : null,
    ));

    if (isKeeper) children.push(opponentNumberBar());

    if (!p) {
      children.push(h('div', { class: 'action-empty' },
        h('p', { class: 'muted' }, 'Erst Spieler links auswählen. Danach Wurfposition im Feld und Trefferzone im Tor antippen, oder direkt eine Aktion wählen.')));
    } else if (pending) {
      children.push(pendingBox(p, isKeeper, pending));
    } else {
      children.push(quickBox(isKeeper));
    }

    actionHost.replaceChildren(...children);
  }

  function opponentNumberBar() {
    const sel = session.opponentNumber;
    const recent = recentOpponentNumbers(session.match).filter((n) => n !== sel).slice(0, 8);
    const input = h('input', {
      class: 'input opp-input',
      type: 'number',
      inputmode: 'numeric',
      min: '1',
      max: '99',
      placeholder: 'Nr.',
      value: sel ?? '',
      'aria-label': 'Trikotnummer Gegner',
      onkeydown: (e) => { if (e.key === 'Enter') e.currentTarget.blur(); },
      onchange: (e) => session.setOpponentNumber(parseOpponentNumber(e.currentTarget.value)),
    });
    return h('div', { class: 'opp-bar' },
      h('div', { class: 'opp-row' },
        h('span', { class: 'opp-label' }, 'Gegner'),
        input,
        sel ? h('button', { class: 'link-btn', type: 'button', onclick: () => session.setOpponentNumber(null) }, 'leeren') : null,
      ),
      recent.length
        ? h('div', { class: 'opp-chips' }, recent.map((n) => h('button', {
          type: 'button', class: 'opp-chip', onclick: () => session.setOpponentNumber(n),
        }, String(n))))
        : null,
      h('p', { class: 'hint-line small' }, sel
        ? `Gegner #${sel}: Wurfposition im Feld antippen (optional), dann Ziel im Tor.`
        : 'Trikotnummer eingeben (1–99), dann Wurfposition im Feld und Ziel im Tor antippen.'),
    );
  }

  function pendingBox(p, isKeeper, pending) {
    const outcomes = isKeeper
      ? [['tor', 'Gegentor', 'tile-bad'], ['wurfGehalten', 'Parade', 'tile-good']]
      : [['tor', 'Tor', 'tile-good'], ['wurfGehalten', 'Gehalten', 'tile-bad'], ['wurfGeblockt', 'Block', 'tile-warn']];
    const ctxLabel = pending.isSevenMeter ? ' · 7-Meter' : (pending.isFreeThrow ? ' · Freiwurf' : '');
    const oppLabel = isKeeper && session.opponentNumber ? `Gegner #${session.opponentNumber} · ` : '';
    const fromLabel = isKeeper && pending.courtZone ? `Von: ${COURT_ZONE_LABELS[pending.courtZone]} · ` : '';
    return h('div', { class: 'action-group' },
      h('div', { class: 'panel-label' }, `${oppLabel}${fromLabel}Ziel: ${GOAL_ZONE_LABELS[pending.goalZone]}${ctxLabel}`),
      h('div', { class: 'tile-grid three' },
        outcomes.map(([type, label, cls]) => h('button', {
          type: 'button', class: `tile big ${cls}`, onclick: () => session.resolvePendingShot(type),
        }, label))),
      h('div', { class: 'panel-label' }, 'Wurfart'),
      h('div', { class: 'segmented wide' },
        seg('Feld', !pending.isSevenMeter && !pending.isFreeThrow, () => session.setThrowContext({ sevenMeter: false, freeThrow: false })),
        seg('7-Meter', pending.isSevenMeter, () => session.setThrowContext({ sevenMeter: true })),
        seg('Freiwurf', pending.isFreeThrow, () => session.setThrowContext({ freeThrow: true })),
      ),
    );
  }

  function quickBox(isKeeper) {
    if (isKeeper) {
      return h('div', { class: 'action-group' },
        h('div', { class: 'panel-label' }, 'Gegnerwurf – Ziel im Tor tippen, dann Gegentor/Parade'),
        h('div', { class: 'tile-grid three' },
          QUICK_KEEPER_OPP.map(([type, label, icon, tone]) => h('button', {
            type: 'button', class: `tile tone-${tone}`, onclick: () => session.commitOpponentAction(type),
          }, icon ? h('span', { class: 'tile-icon' }, icon) : null, h('span', {}, label))),
          h('button', { type: 'button', class: 'tile tone-muted', onclick: () => session.timeout() },
            h('span', {}, 'Auszeit')),
        ),
        h('p', { class: 'hint-line small' }, 'Wurfart (Feld / 7m / Freiwurf) wählen – gilt für Gegner-Fehlwurf und Block.'),
        h('div', { class: 'segmented wide' },
          seg('Feld', !session.lastCourtZone || !['siebenMeter', 'freiwurf'].includes(session.lastCourtZone), () => session.setQuickContext(null)),
          seg('7-Meter', session.lastCourtZone === 'siebenMeter', () => session.onCourtZoneTap('siebenMeter')),
          seg('Freiwurf', session.lastCourtZone === 'freiwurf', () => session.onCourtZoneTap('freiwurf')),
        ),
      );
    }
    return h('div', { class: 'action-group' },
      h('div', { class: 'tile-grid three' },
        QUICK_FIELD.map(([type, label, icon, tone]) => h('button', {
          type: 'button', class: `tile tone-${tone}`, onclick: () => session.commitQuickAction(type),
        }, icon ? h('span', { class: 'tile-icon' }, icon) : null, h('span', {}, label)))),
      h('div', { class: 'panel-label' }, 'Wurfart für Tor-Tipp'),
      h('div', { class: 'segmented wide' },
        seg('Feld', !['siebenMeter', 'freiwurf'].includes(session.lastCourtZone), () => session.setQuickContext(null)),
        seg('7-Meter', session.lastCourtZone === 'siebenMeter', () => session.onCourtZoneTap('siebenMeter')),
        seg('Freiwurf', session.lastCourtZone === 'freiwurf', () => session.onCourtZoneTap('freiwurf')),
      ),
    );
  }

  function seg(label, selected, onClick) {
    return h('button', { type: 'button', class: `seg-btn ${selected ? 'is-active' : ''}`, 'aria-pressed': String(selected), onclick: onClick }, label);
  }

  function paintTimeline() {
    const events = [...session.match.events].reverse().slice(0, 40);
    timelineHost.replaceChildren(events.length === 0
      ? h('p', { class: 'muted small' }, 'Noch keine Aktionen.')
      : h('ul', { class: 'mini-timeline' }, events.map((e) => {
          const p = session.team.players.find((x) => x.id === e.playerId);
          const cls = e.isOpponent ? 'opp' : (['gegentor', 'gegentorSiebenMeter', 'gegentorFreiwurf', 'ballverlust', 'roteKarte'].includes(e.type) ? 'bad' : (['tor', 'parade', 'paradeSiebenMeter', 'paradeFreiwurf', 'duelGewonnen', 'siebenMeterHerausgeholt', 'gefoult'].includes(e.type) ? 'good' : ''));
          return h('li', { class: `mini-item ${cls}` },
            h('span', { class: 'mini-time' }, clock(e.matchClockSec)),
            h('span', { class: 'mini-text' },
              h('strong', {}, EVENT_TYPES[e.type]?.short ?? e.type),
              e.isSevenMeter ? ' (7m)' : '',
              h('span', { class: 'muted' }, p ? ` · #${p.number}` : ''),
              e.isOpponent && e.opponentNumber ? h('span', { class: 'muted' }, ` · Gegner #${e.opponentNumber}`) : null),
            h('button', { class: 'icon-btn tiny', type: 'button', title: 'Aktion löschen', 'aria-label': 'Aktion löschen', onclick: () => session.removeEvent(e.id) }, '✕'),
          );
        })));
  }

  // ------------------------------------------------------------ Dialoge
  function openClockDialog() {
    const m = session.match;
    const current = clock(phaseSeconds(m));
    const input = h('input', { class: 'input big-input', value: current, inputmode: 'numeric', pattern: '[0-9]{1,2}:[0-9]{2}', 'aria-label': 'Spielzeit mm:ss' });
    const err = h('p', { class: 'form-error' });
    openDialog({
      title: `Spielzeit – ${PHASE_LABELS[m.phase]}`,
      submitLabel: 'Setzen',
      body: h('div', { class: 'form-stack' }, input, err,
        h('p', { class: 'muted small' }, 'Format mm:ss, z. B. 12:30. Wirkt auf die aktuelle Halbzeit.')),
      onSubmit: () => {
        const parsed = parseClock(input.value);
        if (parsed === null) { err.textContent = 'Bitte im Format mm:ss eingeben.'; return false; }
        session.setPeriodClock(parsed);
        return true;
      },
    });
  }

  function finishWithConfirm() {
    openDialog({
      title: 'Spiel beenden?',
      submitLabel: 'Beenden',
      danger: true,
      body: h('p', { class: 'muted' }, 'Das Spiel wird als beendet markiert. Danach sind keine Aktionen mehr möglich.'),
      onSubmit: () => { session.finishMatch(); return true; },
    });
  }

  // ------------------------------------------------------------ Tastatur
  function onKey(e) {
    if (disposed) return;
    const tag = (e.target?.tagName ?? '').toLowerCase();
    if (['input', 'textarea', 'select'].includes(tag) || e.target?.isContentEditable) return;
    if (document.querySelector('.overlay')) return; // Dialog offen
    if (e.metaKey || e.ctrlKey || e.altKey) {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'z') {
        e.preventDefault();
        session.undoLastEvent();
      }
      return;
    }
    const key = e.key;
    if (key === ' ') { e.preventDefault(); session.toggleClock(); return; }
    if (key === 'Escape') {
      if (session.pendingShot) session.cancelPendingShot();
      else if (session.selectedPlayerId) session.selectPlayer(session.selectedPlayerId);
      return;
    }
    if (/^[0-9]$/.test(key)) {
      e.preventDefault();
      digitBuffer += key;
      clearTimeout(digitTimer);
      digitTimer = setTimeout(() => {
        const n = Number(digitBuffer);
        digitBuffer = '';
        const p = session.squadPlayers().find((x) => x.number === n);
        if (p) session.selectPlayer(p.id);
        else toast(`Keine Nummer ${n} im Aufgebot`);
      }, SQUAD_NUMBER_TIMEOUT);
      return;
    }
    const k = key.toLowerCase();
    if (k === 'z') { session.undoLastEvent(); return; }
    if (k === 't') {
      if (session.pendingShot) session.resolvePendingShot('tor');
      else if (session.selectedPlayer?.position !== 'torwart') session.commitQuickAction('tor');
      return;
    }
    if (k === 'g') { if (session.pendingShot) session.resolvePendingShot('wurfGehalten'); return; }
    if (k === 'b') { if (session.selectedPlayer?.position !== 'torwart') session.commitQuickAction('ballverlust'); return; }
    if (k === 'f') { if (session.selectedPlayer?.position !== 'torwart') session.commitQuickAction('fehlwurf'); return; }
  }

  // ------------------------------------------------------------ Wake-Lock
  async function updateWakeLock() {
    const want = session.running && !disposed;
    if (want && !wakeLock && navigator.wakeLock?.request) {
      try {
        wakeLock = await navigator.wakeLock.request('screen');
        wakeLock.addEventListener?.('release', () => { wakeLock = null; });
      } catch { wakeLock = null; }
    } else if (!want && wakeLock) {
      wakeLock.release().catch(() => {});
      wakeLock = null;
    }
  }
  const onVisibility = () => { if (document.visibilityState === 'visible') updateWakeLock(); };

  // ------------------------------------------------------------ Start
  document.addEventListener('keydown', onKey);
  document.addEventListener('visibilitychange', onVisibility);
  ready = true;
  setTab('ziel');
  paintAll();

  // Aenderungen von anderen Geraeten (Ereignisse, Uhr): Anzeige aktualisieren, Auswahl bleibt.
  const onRemote = () => session.refresh();
  globalThis.addEventListener('scf-live-refresh', onRemote);

  return {
    node: root,
    dispose() {
      disposed = true;
      globalThis.removeEventListener('scf-live-refresh', onRemote);
      document.removeEventListener('keydown', onKey);
      document.removeEventListener('visibilitychange', onVisibility);
      clearTimeout(digitTimer);
      session.dispose();
      if (wakeLock) { wakeLock.release().catch(() => {}); wakeLock = null; }
    },
  };

  function phaseSeconds(m) {
    switch (m.phase) {
      case 'ersteHalbzeit': return m.firstHalfSec;
      case 'zweiteHalbzeit': return m.secondHalfSec;
      case 'halbzeitpause': return m.pauseSec;
      default: return 0;
    }
  }
}

function markerKind(type) {
  switch (type) {
    case 'tor': case 'gegentor': case 'gegentorSiebenMeter': case 'gegentorFreiwurf': return 'goal';
    case 'wurfGehalten': case 'parade': case 'paradeSiebenMeter': case 'paradeFreiwurf': return 'saved';
    case 'wurfGeblockt': return 'block';
    default: return 'miss';
  }
}

function parseClock(value) {
  const m = /^\s*(\d{1,3}):(\d{1,2})\s*$/.exec(value);
  if (!m) return null;
  const min = Number(m[1]);
  const sec = Number(m[2]);
  if (sec > 59) return null;
  return min * 60 + sec;
}


/** Gegner-Trikotnummer: nur ganze Zahlen 1-99, sonst null. */
function parseOpponentNumber(value) {
  const n = Number.parseInt(String(value).trim(), 10);
  return Number.isInteger(n) && n >= 1 && n <= 99 ? n : null;
}

/** Zuletzt benutzte Gegner-Nummern, neueste zuerst, ohne Doppelte. */
function recentOpponentNumbers(match) {
  const seen = [];
  for (let i = match.events.length - 1; i >= 0; i--) {
    const e = match.events[i];
    if (e.isOpponent && e.opponentNumber && !seen.includes(e.opponentNumber)) seen.push(e.opponentNumber);
  }
  return seen;
}
