// Gegner: Liste aller Mannschaften (neueste oben) und Wurfbilder je gegnerischem Werfer.
import { dateLabel } from '../model.js';
import { courtSvg, goalGridEl } from '../court.js';
import { emptyState, pageHead } from '../components.js';
import { h } from '../ui.js';
import {
  groupOpponentTeams,
  opponentShots,
  shooterNumbers,
  shooterSummary,
  targetTallies,
  teamKey,
} from '../opponents-data.js';

const MARKER_KIND = { goal: 'goal', save: 'saved', miss: 'miss', block: 'block' };

/** Liste aller gegnerischen Mannschaften mit Suche. */
export function renderOpponents({ store, navigate }) {
  const teams = groupOpponentTeams(store.matches);
  if (teams.length === 0) {
    return h('div', { class: 'page' },
      pageHead({ title: 'Gegner', subtitle: 'Wurfbilder der gegnerischen Werfer, nach Mannschaft.' }),
      emptyState({
        title: 'Noch keine Gegner',
        text: 'Lege ein Spiel mit Gegnernamen an, dann erscheinen die Mannschaften hier.',
        action: h('a', { class: 'btn primary', href: '#/spiel/neu' }, 'Spiel anlegen'),
      }),
    );
  }

  const list = h('div', { class: 'team-list' });
  const search = h('input', {
    class: 'input search',
    type: 'search',
    placeholder: 'Mannschaft suchen …',
    'aria-label': 'Mannschaft suchen',
    oninput: () => paint(),
  });

  function paint() {
    const q = teamKey(search.value);
    const shown = teams.filter((t) => !q || t.key.includes(q));
    list.replaceChildren(...(shown.length
      ? shown.map(teamRow)
      : [h('p', { class: 'muted center' }, 'Keine Mannschaft gefunden.')]));
  }

  function teamRow(t) {
    return h('button', {
      type: 'button',
      class: 'team-row',
      onclick: () => navigate(`/gegner/${encodeURIComponent(t.key)}`),
    },
      h('span', { class: 'team-row-name' }, t.name),
      h('span', { class: 'team-row-meta muted small' },
        `${t.matches.length} ${t.matches.length === 1 ? 'Spiel' : 'Spiele'} · ${t.shotCount} Würfe erfasst`),
      h('span', { class: 'team-row-date muted small' }, `zuletzt ${dateLabel(t.lastDate)}`),
    );
  }

  paint();
  return h('div', { class: 'page' },
    pageHead({ title: 'Gegner', subtitle: 'Neueste Mannschaften oben. Mannschaft anklicken für die Wurfbilder.' }),
    h('section', { class: 'card' },
      h('div', { class: 'toolbar' }, search, h('span', { class: 'muted small' }, `${teams.length} Mannschaften`)),
      list,
    ),
  );
}

/** Wurfbilder einer Mannschaft: oben das letzte Spiel, darunter der Gesamt-Ueberblick. */
export function renderOpponentTeam({ store, params }) {
  const key = teamKey(params[0]);
  const team = groupOpponentTeams(store.matches).find((t) => t.key === key);
  if (!team) {
    return emptyState({
      title: 'Mannschaft nicht gefunden',
      action: h('a', { class: 'btn primary', href: '#/gegner' }, 'Zur Liste'),
    });
  }

  const latest = team.matches[0];
  const latestNumbers = shooterNumbers([latest]);
  const allNumbers = shooterNumbers(team.matches);
  const total = shooterSummary(team.matches.flatMap((m) => opponentShots(m)));

  return h('div', { class: 'page' },
    pageHead({
      eyebrow: 'Gegner',
      title: team.name,
      subtitle: `${team.matches.length} ${team.matches.length === 1 ? 'Spiel' : 'Spiele'} · ${total.shots} Würfe · ${total.goals} Tore`,
      actions: [h('a', { class: 'btn ghost sm', href: '#/gegner' }, 'Alle Mannschaften')],
    }),

    h('section', { class: 'card' },
      h('div', { class: 'card-head' },
        h('h2', {}, 'Letztes Spiel'),
        h('span', { class: 'muted small' }, `${dateLabel(latest.date)} · ${latestNumbers.length} Werfer`),
      ),
      latestNumbers.length
        ? h('div', { class: 'shooter-grid' }, latestNumbers.map(({ number }) =>
          shooterCard(number, opponentShots(latest, number))))
        : h('p', { class: 'muted' }, 'Im letzten Spiel wurden keine Gegner-Würfe erfasst.'),
    ),

    h('section', { class: 'card' },
      h('div', { class: 'card-head' },
        h('h2', {}, 'Gesamt-Überblick'),
        h('span', { class: 'muted small' }, `alle ${team.matches.length} Spiele gegen ${team.name}`),
      ),
      allNumbers.length
        ? h('div', { class: 'shooter-grid' }, allNumbers.map(({ number }) =>
          shooterCard(number, team.matches.flatMap((m) => opponentShots(m, number)))))
        : h('p', { class: 'muted' }, 'Noch keine Gegner-Würfe erfasst.'),
    ),
  );
}

/** Eine Karte pro Werfer: Wurfposition im Feld und Ziel im Tor. */
function shooterCard(number, shots) {
  const s = shooterSummary(shots);
  const markers = shots
    .filter((x) => x.origin)
    .map((x) => ({ id: x.id, zone: x.origin, kind: MARKER_KIND[x.outcome] ?? 'miss' }));
  const details = [
    `${s.shots} ${s.shots === 1 ? 'Wurf' : 'Würfe'}`,
    `${s.goals} Tore`,
    `${s.saved} gehalten`,
    `${s.misses} daneben`,
    s.blocks ? `${s.blocks} geblockt` : null,
  ].filter(Boolean).join(' · ');

  return h('article', { class: 'shooter-card' },
    h('header', { class: 'shooter-head' },
      h('span', { class: 'shooter-number' }, number === null ? '–' : String(number)),
      h('div', { class: 'shooter-title' },
        h('strong', {}, number === null ? 'Ohne Nummer' : `Nummer ${number}`),
        h('span', { class: 'muted small' }, details),
      ),
    ),
    h('div', { class: 'shooter-maps' },
      h('figure', { class: 'map-court' },
        courtSvg({ markers, interactive: false }),
        h('figcaption', { class: 'small muted' }, 'Wurfposition'),
      ),
      h('figure', { class: 'map-goal' },
        goalGridEl({ tallies: targetTallies(shots), mode: 'schuetze', disabled: true }),
        h('figcaption', { class: 'small muted' }, 'Ziel im Tor (Tore / Schüsse)'),
      ),
    ),
    h('div', { class: 'shot-legend small' },
      legendItem('goal', 'Tor'), legendItem('save', 'gehalten'), legendItem('miss', 'daneben'), legendItem('block', 'geblockt'),
    ),
  );
}

function legendItem(kind, label) {
  return h('span', { class: 'legend-item' }, h('span', { class: `legend-dot marker-${MARKER_KIND[kind] ?? kind}` }), label);
}
