// Spielerstatistik ueber alle Spiele (Alltime) und Detailansicht je Spieler.
import { dateLabel, playerFullName, PLAYER_POSITIONS, PLAYER_ROLES } from '../model.js';
import { allTimeStatsForPlayer, combineStats, derived, statsForPlayer } from '../stats.js';
import { barChart, dataTable, emptyState, pageHead, positionTag, roleLabel, statCard } from '../components.js';
import { csvPercent, downloadFile, h, sanitizeFilename, toCsv } from '../ui.js';

export function renderStats({ store, navigate }) {
  const matches = store.matchesSorted();
  const players = [...store.team.players].sort((a, b) => a.number - b.number);
  const rows = players.map((p) => {
    const s = allTimeStatsForPlayer(matches, p.id);
    const played = matches.filter((m) => m.squadPlayerIds.includes(p.id) || m.events.some((e) => e.playerId === p.id)).length;
    return { player: p, s, d: derived(s), played };
  });

  const total = combineStats(rows.map((r) => r.s));
  const totalD = derived(total);

  const columns = [
    { key: 'number', label: '#', numeric: true, sort: (r) => r.player.number, render: (r) => String(r.player.number) },
    { key: 'name', label: 'Spieler', sort: (r) => playerFullName(r.player), render: (r) => h('span', { class: 'player-cell' },
      h('span', { class: 'jersey-mini' }, String(r.player.number)), playerFullName(r.player)) },
    { key: 'played', label: 'Spiele', numeric: true, render: (r) => String(r.played), sort: (r) => r.played },
    { key: 'shots', label: 'Würfe', numeric: true, render: (r) => String(r.s.shots), sort: (r) => r.s.shots },
    { key: 'goals', label: 'Tore', numeric: true, render: (r) => h('strong', {}, String(r.s.goals)), sort: (r) => r.s.goals },
    { key: 'quote', label: 'Quote', numeric: true, render: (r) => pct(r.d.shotRatio), sort: (r) => r.d.shotRatio },
    { key: 'seven', label: '7m', numeric: true, title: '7-Meter-Tore', render: (r) => `${r.s.goalsSevenMeter}/${r.s.shotsSevenMeter}`, sort: (r) => r.s.goalsSevenMeter },
    { key: 'saves', label: 'Paraden', numeric: true, render: (r) => String(r.s.saves), sort: (r) => r.s.saves },
    { key: 'saveQuote', label: 'P-Quote', numeric: true, render: (r) => pct(r.d.saveRatio), sort: (r) => r.d.saveRatio },
    { key: 'conceded', label: 'GT', numeric: true, title: 'Gegentore', render: (r) => String(r.s.conceded), sort: (r) => r.s.conceded },
    { key: 'bv', label: 'BV', numeric: true, title: 'Ballverluste', render: (r) => String(r.s.ballLosses), sort: (r) => r.s.ballLosses },
    { key: 'tech', label: 'Technik', numeric: true, render: (r) => String(r.d.technicalErrors), sort: (r) => r.d.technicalErrors },
    { key: 'duels', label: 'Duelle', numeric: true, render: (r) => String(r.s.duelsWon), sort: (r) => r.s.duelsWon },
    { key: 'sanctions', label: 'Strafen', numeric: true, render: (r) => String(r.d.sanctions), sort: (r) => r.d.sanctions },
  ];

  const table = rows.length
    ? dataTable({
        columns,
        rows,
        sortKey: 'goals',
        sortDir: 'desc',
        onRowClick: (r) => navigate(`/statistik/${r.player.id}`),
        footer: ['Team', '', '', String(total.shots), String(total.goals), pct(totalD.shotRatio), `${total.goalsSevenMeter}/${total.shotsSevenMeter}`, String(total.saves), pct(derived(total).saveRatio), String(total.conceded), String(total.ballLosses), String(totalD.technicalErrors), String(total.duelsWon), String(totalD.sanctions)],
        caption: 'Spielerstatistik alle Zeiten',
      })
    : emptyState({ icon: '📊', title: 'Noch keine Spieler', text: 'Lege zuerst den Kader an.', action: h('a', { class: 'btn primary', href: '#/kader' }, 'Zum Kader') });

  const exportBtn = h('button', {
    class: 'btn ghost', type: 'button', onclick: () => {
      const header = ['Nummer', 'Spieler', 'Spiele', 'Würfe', 'Tore', 'Quote %', '7m Tore', '7m Würfe', 'Geblockt', 'Paraden', 'Paradenquote %', 'Gegentore', 'Ballverluste', 'Technikfehler', 'Duelle gew.', 'Gelb', '2min', 'Rot', 'Blau'];
      const data = rows.map((r) => [r.player.number, playerFullName(r.player), r.played, r.s.shots, r.s.goals, csvPercent(r.d.shotRatio), r.s.goalsSevenMeter, r.s.shotsSevenMeter, r.s.blocked, r.s.saves, csvPercent(r.d.saveRatio), r.s.conceded, r.s.ballLosses, r.d.technicalErrors, r.s.duelsWon, r.s.yellowCards, r.s.twoMinutes, r.s.redCards, r.s.blueCards]);
      downloadFile('SCF_Spielerstatistik_alle_Zeiten.csv', toCsv([header, ...data]), 'text/csv;charset=utf-8');
    },
  }, 'CSV exportieren');

  return h('div', { class: 'page' },
    pageHead({
      eyebrow: 'Alle Spiele',
      title: 'Spielerstatistik',
      subtitle: `Summe aller ${matches.length} Spiele. Zeile anklicken für die Detailansicht je Spieler.`,
      actions: [exportBtn],
    }),
    h('section', { class: 'kpi-grid' },
      statCard({ label: 'Spiele', value: matches.length, icon: '🏟' }),
      statCard({ label: 'Tore gesamt', value: total.goals, sub: `Quote ${pct(totalD.shotRatio)}`, tone: 'accent', icon: '⚽' }),
      statCard({ label: 'Paraden gesamt', value: total.saves, sub: `Quote ${pct(derived(total).saveRatio)}`, tone: 'cyan', icon: '🧤' }),
      statCard({ label: 'Ballverluste', value: total.ballLosses, sub: `${totalD.technicalErrors} Technikfehler`, tone: 'warn', icon: '🔄' }),
    ),
    h('section', { class: 'card table-card' }, table),
  );
}

export function renderPlayerDetail({ store, navigate, params }) {
  const player = store.team.players.find((p) => p.id === params[0]);
  if (!player) {
    return emptyState({ icon: '?', title: 'Spieler nicht gefunden', action: h('a', { class: 'btn primary', href: '#/statistik' }, 'Zur Statistik') });
  }
  const allMatches = store.matchesSorted();
  const chronological = [...allMatches].reverse();
  const isKeeper = player.position === 'torwart';

  const rows = [];
  for (const m of chronological) {
    const s = statsForPlayer(m, player.id);
    const inSquad = m.squadPlayerIds.length === 0 || m.squadPlayerIds.includes(player.id);
    if (!inSquad && m.events.every((e) => e.playerId !== player.id)) continue;
    rows.push({ match: m, s, d: derived(s) });
  }
  const total = combineStats(rows.map((r) => r.s));
  const totalD = derived(total);

  const columns = [
    { key: 'date', label: 'Datum', sort: (r) => r.match.date, render: (r) => dateLabel(r.match.date) },
    { key: 'opp', label: 'Gegner', sort: (r) => r.match.opponentName, render: (r) => h('span', {}, r.match.opponentName || '–') },
    { key: 'shots', label: 'Würfe', numeric: true, render: (r) => String(r.s.shots), sort: (r) => r.s.shots },
    { key: 'goals', label: 'Tore', numeric: true, render: (r) => String(r.s.goals), sort: (r) => r.s.goals },
    { key: 'quote', label: 'Quote', numeric: true, render: (r) => pct(r.d.shotRatio), sort: (r) => r.d.shotRatio },
    { key: 'seven', label: '7m', numeric: true, render: (r) => `${r.s.goalsSevenMeter}/${r.s.shotsSevenMeter}`, sort: (r) => r.s.goalsSevenMeter },
    { key: 'saves', label: 'Paraden', numeric: true, render: (r) => String(r.s.saves), sort: (r) => r.s.saves },
    { key: 'pq', label: 'P-Quote', numeric: true, render: (r) => pct(r.d.saveRatio), sort: (r) => r.d.saveRatio },
    { key: 'gt', label: 'GT', numeric: true, render: (r) => String(r.s.conceded), sort: (r) => r.s.conceded },
    { key: 'bv', label: 'BV', numeric: true, render: (r) => String(r.s.ballLosses), sort: (r) => r.s.ballLosses },
    { key: 'tech', label: 'Technik', numeric: true, render: (r) => String(r.d.technicalErrors), sort: (r) => r.d.technicalErrors },
    { key: 'straf', label: 'Strafen', numeric: true, render: (r) => String(r.d.sanctions), sort: (r) => r.d.sanctions },
  ];

  // Verlaufs-Diagramm: Tore (Feld) bzw. Paraden je Spiel
  const chart = rows.length
    ? barChart(rows.map((r) => ({
        label: r.match.opponentName ? r.match.opponentName.slice(0, 6) : dateLabel(r.match.date).slice(0, 5),
        value: isKeeper ? r.s.saves : r.s.goals,
        title: `${dateLabel(r.match.date)} · ${r.match.opponentName}: ${isKeeper ? r.s.saves + ' Paraden' : r.s.goals + ' Tore'}`,
      })))
    : null;

  const exportBtn = h('button', {
    class: 'btn ghost', type: 'button', onclick: () => {
      const header = ['Datum', 'Gegner', 'Würfe', 'Tore', 'Quote %', '7m Tore', 'Geblockt', 'Technikfehler', 'Ballverluste', 'Paraden', 'Gegentore', 'Gelb', '2min', 'Rot', 'Blau'];
      const data = rows.map((r) => [dateLabel(r.match.date), r.match.opponentName, r.s.shots, r.s.goals, csvPercent(r.d.shotRatio), r.s.goalsSevenMeter, r.s.blocked, r.d.technicalErrors, r.s.ballLosses, r.s.saves, r.s.conceded, r.s.yellowCards, r.s.twoMinutes, r.s.redCards, r.s.blueCards]);
      data.push(['GESAMT', '', total.shots, total.goals, csvPercent(totalD.shotRatio), total.goalsSevenMeter, total.blocked, totalD.technicalErrors, total.ballLosses, total.saves, total.conceded, total.yellowCards, total.twoMinutes, total.redCards, total.blueCards]);
      downloadFile(sanitizeFilename(`SCF_${playerFullName(player)}_alle_Spiele`) + '.csv', toCsv([header, ...data]), 'text/csv;charset=utf-8');
    },
  }, 'CSV exportieren');

  const table = rows.length
    ? dataTable({
        columns,
        rows,
        sortKey: 'date',
        sortDir: 'desc',
        onRowClick: (r) => navigate(`/spiel/${r.match.id}`),
        footer: ['Gesamt', '', String(total.shots), String(total.goals), pct(totalD.shotRatio), `${total.goalsSevenMeter}/${total.shotsSevenMeter}`, String(total.saves), pct(derived(total).saveRatio), String(total.conceded), String(total.ballLosses), String(totalD.technicalErrors), String(totalD.sanctions)],
      })
    : emptyState({ icon: '📋', title: 'Noch keine Spiele', text: 'Dieser Spieler hat noch in keinem Spiel mitgewirkt.' });

  return h('div', { class: 'page' },
    h('nav', { class: 'breadcrumb no-print' }, h('a', { href: '#/statistik' }, 'Statistik'), ' / ', h('span', {}, playerFullName(player))),
    pageHead({
      eyebrow: `#${player.number} · ${PLAYER_POSITIONS[player.position]}`,
      title: playerFullName(player),
      subtitle: player.gameRole !== 'keine' ? PLAYER_ROLES[player.gameRole] : '',
      actions: [exportBtn, h('a', { class: 'btn ghost', href: '#/kader' }, 'Kader')],
    }),
    h('div', { class: 'tags-row' }, positionTag(player), player.gameRole !== 'keine' ? h('span', { class: 'tag' }, roleLabel(player.gameRole)) : null),
    h('section', { class: 'kpi-grid' },
      isKeeper
        ? statCard({ label: 'Paraden', value: total.saves, sub: `Quote ${pct(derived(total).saveRatio)}`, tone: 'cyan', icon: '🧤' })
        : statCard({ label: 'Tore', value: total.goals, sub: `von ${total.shots} Würfen · ${pct(totalD.shotRatio)}`, tone: 'accent', icon: '🎯' }),
      isKeeper
        ? statCard({ label: 'Gegentore', value: total.conceded, sub: `7m ${total.concededSevenMeter} · FW ${total.concededFreeThrow}`, tone: 'warn', icon: '🥅' })
        : statCard({ label: '7-Meter', value: `${total.goalsSevenMeter}/${total.shotsSevenMeter}`, sub: `${total.sevenMeterWon} herausgeholt`, tone: 'violet', icon: '7️⃣' }),
      statCard({ label: 'Spiele', value: rows.length, sub: `${allMatches.length} gesamt`, icon: '🏟' }),
      statCard({ label: 'Strafen', value: totalD.sanctions, sub: `${total.twoMinutes} × 2 min · ${total.yellowCards} Gelb`, icon: '⏱' }),
    ),
    rows.length
      ? h('section', { class: 'card' },
          h('div', { class: 'card-head' }, h('h2', {}, isKeeper ? 'Paraden je Spiel' : 'Tore je Spiel'), h('span', { class: 'muted small' }, 'chronologisch')),
          chart)
      : null,
    h('section', { class: 'card table-card' },
      h('div', { class: 'card-head' }, h('h2', {}, 'Spiele'), h('span', { class: 'muted small' }, 'Zeile anklicken für das Spiel')),
      table),
  );
}

export function pct(ratio) {
  if (ratio === null || Number.isNaN(ratio)) return '–';
  return `${Math.round(ratio * 100)}%`;
}

