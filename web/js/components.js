// Wiederverwendbare Bausteine der Oberflaeche.
import { dateLabel, EVENT_TYPES, percent, PLAYER_POSITIONS, PLAYER_ROLES, playerFullName } from './model.js';
import { resultOf, scoreOf } from './stats.js';
import { h } from './ui.js';

export function pageHead({ eyebrow = '', title, subtitle = '', actions = [] }) {
  return h('header', { class: 'page-head' },
    h('div', { class: 'page-head-text' },
      eyebrow ? h('p', { class: 'eyebrow' }, eyebrow) : null,
      h('h1', {}, title),
      subtitle ? h('p', { class: 'lead' }, subtitle) : null,
    ),
    actions.length ? h('div', { class: 'page-head-actions' }, actions) : null,
  );
}

export function statCard({ label, value, sub = '', tone = '', icon = '' }) {
  return h('div', { class: `stat-card ${tone ? 'tone-' + tone : ''}` },
    h('div', { class: 'stat-label' }, icon ? h('span', { class: 'stat-icon', 'aria-hidden': 'true' }, icon) : null, label),
    h('div', { class: 'stat-value' }, String(value)),
    sub ? h('div', { class: 'stat-sub' }, sub) : null,
  );
}

export function statusPill(match) {
  if (match.status === 'laufend') return h('span', { class: 'pill pill-live' }, h('i', { class: 'dot' }), 'LIVE');
  if (match.status === 'beendet') return h('span', { class: 'pill pill-done' }, 'Beendet');
  return h('span', { class: 'pill pill-plan' }, 'Geplant');
}

export function resultPill(match) {
  const r = resultOf(match);
  if (!r) return null;
  const map = { sieg: ['S', 'pill-win', 'Sieg'], remis: ['U', 'pill-draw', 'Unentschieden'], niederlage: ['N', 'pill-loss', 'Niederlage'] };
  const [short, cls, label] = map[r];
  return h('span', { class: `pill ${cls}`, title: label }, short);
}

export function scoreText(match) {
  const { goalsFor, goalsAgainst } = scoreOf(match);
  return { goalsFor, goalsAgainst, text: `${goalsFor} : ${goalsAgainst}` };
}

export function homeAwayTag(match) {
  return h('span', { class: 'tag' }, match.isHome ? 'Heim' : 'Auswärts');
}

export function positionTag(player) {
  const isKeeper = player.position === 'torwart';
  return h('span', { class: `tag ${isKeeper ? 'tag-cyan' : 'tag-orange'}` }, PLAYER_POSITIONS[player.position] ?? '');
}

export function roleLabel(role) {
  return PLAYER_ROLES[role] ?? '';
}

export function emptyState({ icon = '○', title, text = '', action = null }) {
  return h('div', { class: 'empty' },
    h('div', { class: 'empty-icon', 'aria-hidden': 'true' }, icon),
    h('h3', {}, title),
    text ? h('p', { class: 'muted' }, text) : null,
    action,
  );
}

/** Kleine Balkengrafik: values = [{label, value, title?}] */
export function barChart(values, { unit = '' } = {}) {
  const max = Math.max(1, ...values.map((v) => v.value));
  return h('div', { class: 'bars' },
    values.map((v) => h('div', { class: 'bar-col', title: v.title ?? `${v.label}: ${v.value}${unit}` },
      h('span', { class: 'bar-value' }, String(v.value)),
      h('div', { class: 'bar', style: { height: `${Math.max(3, (v.value / max) * 100)}%` } }),
      h('span', { class: 'bar-label' }, v.label),
    )),
  );
}

/**
 * Sortierbare Tabelle.
 * columns: [{ key, label, numeric?, sort?(row)=>value, render?(row)=>node|string, sortable=true, className }]
 * rows: Array; rowKey(row) => string; onRowClick(row)
 */
export function dataTable({ columns, rows, sortKey = null, sortDir = 'desc', onRowClick = null, rowClass = null, footer = null, caption = '' }) {
  let currentKey = sortKey;
  let currentDir = sortDir;
  const wrap = h('div', { class: 'table-wrap' });
  const table = h('table', { class: 'data-table' });
  if (caption) table.append(h('caption', { class: 'sr-only' }, caption));

  const sortedRows = () => {
    const col = columns.find((c) => c.key === currentKey);
    if (!col) return rows;
    const value = col.sort ?? ((row) => row[col.key]);
    const factor = currentDir === 'asc' ? 1 : -1;
    return [...rows].sort((a, b) => {
      const va = value(a);
      const vb = value(b);
      const na = typeof va === 'number' && !Number.isNaN(va);
      const nb = typeof vb === 'number' && !Number.isNaN(vb);
      if (na && nb) return (va - vb) * factor;
      if (na !== nb) return na ? -1 : 1; // NaN ans Ende
      return String(va ?? '').localeCompare(String(vb ?? ''), 'de') * factor;
    });
  };

  const draw = () => {
    const thead = h('thead', {}, h('tr', {},
      columns.map((c) => {
        const active = currentKey === c.key;
        const sortable = c.sortable !== false;
        return h('th', {
          class: `${c.numeric ? 'num' : ''} ${sortable ? 'sortable' : ''} ${active ? 'is-sorted' : ''}`,
          scope: 'col',
          title: c.title ?? c.label,
          onclick: sortable ? () => {
            if (currentKey === c.key) currentDir = currentDir === 'asc' ? 'desc' : 'asc';
            else { currentKey = c.key; currentDir = c.numeric ? 'desc' : 'asc'; }
            draw();
          } : null,
        },
          c.label,
          sortable ? h('span', { class: 'sort-ind' }, active ? (currentDir === 'asc' ? ' ▲' : ' ▼') : '') : null,
        );
      }),
    ));
    const tbody = h('tbody', {}, sortedRows().map((row) => h('tr', {
      class: [onRowClick ? 'clickable' : '', rowClass ? rowClass(row) : ''].join(' '),
      onclick: onRowClick ? () => onRowClick(row) : null,
    },
      columns.map((c) => {
        const value = c.render ? c.render(row) : formatValue(c.sort ? c.sort(row) : row[c.key]);
        return h('td', { class: `${c.numeric ? 'num' : ''} ${c.className ?? ''}` }, value);
      }),
    )));
    const tfoot = footer ? h('tfoot', {}, h('tr', {}, footer.map((cell, i) => h('td', { class: columns[i]?.numeric ? 'num' : '' }, cell)))) : null;
    table.replaceChildren(...[...(caption ? [h('caption', { class: 'sr-only' }, caption)] : []), thead, tbody, tfoot].filter(Boolean));
  };

  draw();
  wrap.append(table);
  return wrap;
}

function formatValue(v) {
  if (v === null || v === undefined) return '–';
  if (typeof v === 'number') return Number.isNaN(v) ? '–' : String(v);
  return String(v);
}

/** Prozentwert-Zelle fuer Tabellen. */
export const pctCell = (ratio) => percent(ratio);

export function playerLabelNode(player) {
  return h('span', { class: 'player-cell' },
    h('span', { class: 'jersey-mini' }, String(player.number)),
    h('span', {}, playerFullName(player)),
  );
}

export function eventTypeLabel(type) {
  return EVENT_TYPES[type]?.label ?? type;
}

export function formatMatchTitle(match) {
  return `${match.isHome ? 'SCF vs.' : 'bei'} ${match.opponentName || 'Gegner'}`;
}

export function matchDateLabel(match) {
  return dateLabel(match.date);
}
