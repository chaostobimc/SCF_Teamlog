// Startseite: Saisonueberblick, laufendes Spiel, Spielliste.
import { dateLabel, SCF_TEAM_NAME } from '../model.js';
import { resultOf, scoreOf, derived, teamStats } from '../stats.js';
import { emptyState, homeAwayTag, pageHead, resultPill, scoreText, statCard, statusPill } from '../components.js';
import { h } from '../ui.js';

export function renderHome({ store }) {
  const matches = store.matchesSorted();
  const live = matches.find((m) => m.status === 'laufend');
  const finished = matches.filter((m) => m.status === 'beendet');

  const wins = finished.filter((m) => resultOf(m) === 'sieg').length;
  const draws = finished.filter((m) => resultOf(m) === 'remis').length;
  const losses = finished.filter((m) => resultOf(m) === 'niederlage').length;
  let goalsFor = 0;
  let goalsAgainst = 0;
  for (const m of matches) {
    const s = scoreOf(m);
    goalsFor += s.goalsFor;
    goalsAgainst += s.goalsAgainst;
  }
  const playerCount = store.team.players.length;
  const next = matches.find((m) => m.status === 'geplant') ?? null;
  const last = finished[0] ?? null;

  const hero = h('section', { class: 'hero' },
    h('div', { class: 'hero-glow', 'aria-hidden': 'true' }),
    h('div', { class: 'hero-inner' },
      h('div', { class: 'hero-brand' },
        h('img', { class: 'logo-img hero-logo', src: 'img/logo.svg', alt: 'SC Freising Logo' }),
        h('div', {},
          h('h1', { class: 'hero-title' }, 'SCF Teamlog'),
        ),
      ),
      h('div', { class: 'hero-actions' },
        live
          ? h('a', { class: 'btn primary xl', href: `#/spiel/${live.id}/live` }, h('i', { class: 'dot live-dot' }), `Weiter: ${live.opponentName || 'Spiel'} ansehen`)
          : h('a', { class: 'btn primary xl', href: '#/spiel/neu' }, 'Spiel starten'),
        h('a', { class: 'btn ghost lg', href: '#/kader' }, `Kader (${playerCount})`),
        h('a', { class: 'btn ghost lg', href: '#/statistik' }, 'Statistik'),
      ),
    ),
  );

  const kpis = h('section', { class: 'kpi-grid' },
    statCard({ label: 'Spiele', value: matches.length, sub: `${finished.length} beendet` }),
    statCard({ label: 'Bilanz', value: `${wins} · ${draws} · ${losses}`, sub: 'Siege · Unentschieden · Niederlagen', tone: 'accent' }),
    statCard({ label: 'Tore', value: `${goalsFor} : ${goalsAgainst}`, sub: 'erzielt : kassiert', tone: 'cyan' }),
    statCard({ label: 'Ø Tore', value: matches.length ? (goalsFor / matches.length).toFixed(1).replace('.', ',') : '–', sub: 'pro Spiel', tone: 'violet' }),
  );

  const formStrip = last ? h('section', { class: 'card last-match' },
    h('div', { class: 'card-head' },
      h('h2', {}, 'Letztes Spiel'),
      h('a', { class: 'link', href: `#/spiel/${last.id}` }, 'Auswertung →'),
    ),
    matchRowBig(last),
  ) : null;

  const filterState = { filter: 'alle', query: '' };
  const listHost = h('div', { class: 'match-list' });
  const filterBar = h('div', { class: 'toolbar' },
    h('div', { class: 'chips', role: 'group', 'aria-label': 'Filter' },
      ['alle', 'laufend', 'geplant', 'beendet'].map((f) => h('button', {
        class: 'chip', type: 'button', 'aria-pressed': 'false', dataset: { filter: f },
        onclick: () => { filterState.filter = f; paint(); },
      }, { alle: 'Alle', laufend: 'Live', geplant: 'Geplant', beendet: 'Beendet' }[f]))),
    h('input', {
      class: 'input search', type: 'search', placeholder: 'Gegner suchen …', 'aria-label': 'Spiele suchen',
      oninput: (e) => { filterState.query = e.target.value.trim().toLowerCase(); paint(); },
    }),
  );

  const paint = () => {
    for (const chip of filterBar.querySelectorAll('.chip')) {
      const active = chip.dataset.filter === filterState.filter;
      chip.classList.toggle('is-active', active);
      chip.setAttribute('aria-pressed', String(active));
    }
    const shown = matches.filter((m) => {
      if (filterState.filter !== 'alle') {
        const map = { laufend: 'laufend', geplant: 'geplant', beendet: 'beendet' };
        if (m.status !== map[filterState.filter]) return false;
      }
      if (filterState.query && !(m.opponentName ?? '').toLowerCase().includes(filterState.query)) return false;
      return true;
    });
    listHost.replaceChildren(
      ...(matches.length === 0
        ? [emptyState({
            title: 'Noch keine Spiele',
            text: 'Lege dein erstes Spiel an und erfasse Aktionen live.',
            action: h('a', { class: 'btn primary', href: '#/spiel/neu' }, 'Erstes Spiel anlegen'),
          })]
        : shown.length === 0
          ? [h('p', { class: 'muted center' }, 'Keine Spiele für diesen Filter.')]
          : shown.map(matchRow)),
    );
  };
  paint();

  const node = h('div', { class: 'page home' },
    hero,
    kpis,
    h('div', { class: 'grid-2' },
      h('div', {}, next && !live ? nextCard(next) : null, formStrip),
      h('section', { class: 'card' },
        h('div', { class: 'card-head' },
          h('h2', {}, 'Spielverlauf'),
          h('span', { class: 'muted small' }, `${matches.length} Spiele`),
        ),
        filterBar,
        listHost,
      ),
    ),
    h('p', { class: 'footnote' },
      'Alle Daten bleiben auf diesem Gerät. Sicherung und Wiederherstellung unter ',
      h('a', { href: '#/daten' }, 'Daten'), '.'),
  );
  return node;
}

function nextCard(match) {
  return h('section', { class: 'card next-card' },
    h('div', { class: 'card-head' }, h('h2', {}, 'Nächstes Spiel')),
    matchRowBig(match),
    h('a', { class: 'btn primary block', href: `#/spiel/${match.id}/live` }, 'Live erfassen'),
  );
}

function matchRowBig(match) {
  const score = scoreText(match);
  const played = match.status !== 'geplant' || match.events.length > 0;
  return h('a', { class: 'match-big', href: `#/spiel/${match.id}` },
    h('div', { class: 'match-big-main' },
      h('div', { class: 'match-big-title' }, match.opponentName || 'Gegner'),
      h('div', { class: 'match-big-meta' },
        dateLabel(match.date), ' · ', homeAwayTag(match), ' · ', `${match.halfLengthMin} min`),
    ),
    h('div', { class: 'match-big-score' },
      played ? h('span', { class: 'score' }, `${score.goalsFor}:${score.goalsAgainst}`) : h('span', { class: 'muted' }, 'vs.'),
      statusPill(match),
    ),
  );
}

function matchRow(match) {
  const score = scoreText(match);
  const stats = derived(teamStats(match).total);
  const hasEvents = match.events.length > 0;
  return h('a', { class: `match-row status-${match.status}`, href: match.status === 'laufend' ? `#/spiel/${match.id}/live` : `#/spiel/${match.id}` },
    h('div', { class: 'match-row-date' },
      h('span', { class: 'day' }, new Date(match.date).getDate().toString().padStart(2, '0')),
      h('span', { class: 'month' }, new Date(match.date).toLocaleString('de-DE', { month: 'short' })),
    ),
    h('div', { class: 'match-row-main' },
      h('div', { class: 'match-row-title' }, match.opponentName || 'Gegner'),
      h('div', { class: 'match-row-meta' },
        homeAwayTag(match),
        hasEvents ? h('span', { class: 'muted' }, `${match.events.length} Ereignisse · Quote ${Number.isNaN(stats.shotRatio) ? '–' : Math.round(stats.shotRatio * 100) + '%'}`) : h('span', { class: 'muted' }, 'noch keine Aktionen'),
      ),
    ),
    h('div', { class: 'match-row-end' },
      hasEvents || match.status === 'beendet' ? h('span', { class: 'score' }, score.text) : null,
      resultPill(match),
      statusPill(match),
    ),
  );
}
