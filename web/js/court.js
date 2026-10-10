// Spielfeld (halbes Feld aus Angriffssicht) und Tor-Raster als SVG/DOM.
// Geometrie und Zonen-Logik entsprechen lib/features/live/widgets/handball_court.dart
// und goal_grid.dart.
import { GOAL_ZONE_LABELS } from './model.js';
import { h, svg } from './ui.js';

export const W = 600;
export const H = 414;
const GC = { x: W / 2, y: 8 };
const R6 = H * 0.52;
const R9 = H * 0.95;
const R_MAX = Math.hypot(W / 2 + 6, H + 6);
const SEVEN = { x: W / 2, y: GC.y + R6 + (R9 - R6) * 0.28 };

/** Winkel (0 = senkrecht nach unten, + = rechts) in Punkt auf Kreis um GC. */
function polar(r, thetaDeg) {
  const t = (thetaDeg * Math.PI) / 180;
  return { x: GC.x + r * Math.sin(t), y: GC.y + r * Math.cos(t) };
}

const SECTORS = [
  ['aussenLinks', -90, -62],
  ['rueckraumLinks', -62, -28],
  ['rueckraumMitte', -28, 28],
  ['rueckraumRechts', 28, 62],
  ['aussenRechts', 62, 90],
];

/** Zone anhand einer Position im Spielfeld-Koordinatensystem (wie Flutter). */
export function zoneAt(x, y) {
  const dx = x - GC.x;
  const dy = y - GC.y;
  if (dy < -2) return null;
  if (Math.hypot(x - SEVEN.x, y - SEVEN.y) < W * 0.055) return 'siebenMeter';
  if (Math.hypot(dx, dy) <= R6) return 'kreis';
  const angle = (Math.atan2(dx, Math.max(dy, 0.1)) * 180) / Math.PI;
  const abs = Math.abs(angle);
  const left = angle < 0;
  if (abs <= 28) return 'rueckraumMitte';
  if (abs <= 62) return left ? 'rueckraumLinks' : 'rueckraumRechts';
  return left ? 'aussenLinks' : 'aussenRechts';
}

/** Mittelpunkt einer Zone (fuer Beschriftungen und Wurfmarker). */
export function zoneCenter(zone) {
  switch (zone) {
    case 'aussenLinks': return polar(R6 * 1.25, -75);
    case 'rueckraumLinks': return polar(R6 * 1.25, -45);
    case 'rueckraumMitte': return polar(R6 * 1.25, 0);
    case 'rueckraumRechts': return polar(R6 * 1.25, 45);
    case 'aussenRechts': return polar(R6 * 1.25, 75);
    case 'kreis': return polar(R6 * 0.6, 18);
    case 'siebenMeter': return { x: SEVEN.x, y: SEVEN.y };
    case 'freiwurf': return polar(R6 * 1.5, 0);
    default: return { x: W / 2, y: H / 2 };
  }
}

function hashCode(str) {
  let hash = 0;
  for (let i = 0; i < str.length; i++) hash = (hash * 31 + str.charCodeAt(i)) | 0;
  return Math.abs(hash);
}

function sectorPath(startDeg, endDeg) {
  const steps = 24;
  const pts = [];
  for (let i = 0; i <= steps; i++) {
    const t = startDeg + ((endDeg - startDeg) * i) / steps;
    pts.push(polar(R6, t));
  }
  for (let i = steps; i >= 0; i--) {
    const t = startDeg + ((endDeg - startDeg) * i) / steps;
    pts.push(polar(R_MAX, t));
  }
  return 'M' + pts.map((p) => `${p.x.toFixed(1)} ${p.y.toFixed(1)}`).join(' L') + ' Z';
}

function arcPoints(radius, fromDeg, toDeg, steps = 60) {
  const pts = [];
  for (let i = 0; i <= steps; i++) {
    pts.push(polar(radius, fromDeg + ((toDeg - fromDeg) * i) / steps));
  }
  return 'M' + pts.map((p) => `${p.x.toFixed(1)} ${p.y.toFixed(1)}`).join(' L');
}

/**
 * Spielfeld als SVG.
 * opts.selected  aktuell gewaehlte Zone (hervorgehoben)
 * opts.onZone    Callback(zone) beim Tippen
 * opts.markers   Wurfmarker: [{id, zone, kind: 'goal'|'saved'|'miss'|'block'|'seven'}]
 * opts.heat      { zone: { value, label? } } Einfaerbung + Beschriftung (Auswertung)
 */
export function courtSvg({ selected = null, onZone = null, markers = [], heat = null, interactive = true } = {}) {
  const maxHeat = heat ? Math.max(1, ...Object.values(heat).map((v) => v.value)) : 1;
  const root = svg('svg', {
    viewBox: `0 0 ${W} ${H}`,
    class: 'court' + (interactive ? ' court-interactive' : ''),
    role: 'img',
    'aria-label': 'Spielfeld – Wurfzonen',
    preserveAspectRatio: 'xMidYMid meet',
  });

  root.append(svg('rect', { x: 0, y: 0, width: W, height: H, class: 'court-bg' }));

  // Sektoren (Zonen ausserhalb des Kreises)
  SECTORS.forEach(([zone, a, b], index) => {
    const isSel = selected === zone;
    const heatValue = heat?.[zone]?.value ?? 0;
    const path = svg('path', {
      d: sectorPath(a, b),
      class: 'zone-sector' + (isSel ? ' is-selected' : ''),
      'data-zone': zone,
      fill: heat ? heatColor(heatValue / maxHeat) : null,
      'fill-opacity': heat ? 0.25 + 0.55 * (heatValue / maxHeat) : null,
    });
    if (!heat) path.classList.add(index % 2 === 0 ? 'zone-a' : 'zone-b');
    root.append(path);
  });

  // Kreis (Torwartraum)
  root.append(svg('path', {
    d: `M${GC.x - R6} ${GC.y} A${R6} ${R6} 0 0 0 ${GC.x + R6} ${GC.y} Z`,
    class: 'zone-kreis' + (selected === 'kreis' ? ' is-selected' : ''),
    'data-zone': 'kreis',
  }));

  // 9-m-Linie (gestrichelt) und 6-m-Linie
  root.append(svg('path', { d: arcPoints(R9, -50, 50), class: 'court-line dashed', fill: 'none' }));
  root.append(svg('path', {
    d: `M${GC.x - R6} ${GC.y} A${R6} ${R6} 0 0 0 ${GC.x + R6} ${GC.y}`,
    class: 'court-line', fill: 'none',
  }));
  // Seitenlinien und Torlinie
  root.append(svg('path', { d: `M1 0 V${H} M${W - 1} 0 V${H} M0 ${H - 1} H${W}`, class: 'court-line thin', fill: 'none' }));
  // Tor
  root.append(svg('rect', { x: GC.x - 44, y: -4, width: 88, height: 12, rx: 2, class: 'goal-frame' }));
  // 7-m-Punkt
  root.append(svg('circle', { cx: SEVEN.x, cy: SEVEN.y, r: 3.5, class: 'seven-dot' }));

  // Heat-Beschriftungen
  if (heat) {
    for (const [zone, info] of Object.entries(heat)) {
      if (!info.label) continue;
      const c = zoneCenter(zone);
      root.append(svg('text', { x: c.x, y: c.y + 9, class: 'heat-label', 'text-anchor': 'middle' }, info.label));
    }
  }

  // Wurfmarker
  for (const m of markers) {
    if (!m.zone) continue;
    const c = zoneCenter(m.zone);
    const seed = hashCode(m.id ?? '');
    const jx = (seed % 9) - 4;
    const jy = ((seed >> 4) % 7) - 3;
    const cls = `marker marker-${m.kind}`;
    root.append(svg('circle', { cx: c.x + jx, cy: c.y + jy, r: 6, class: cls }));
  }

  if (onZone && interactive) {
    root.addEventListener('click', (e) => {
      const pt = toCourtPoint(root, e);
      const zone = zoneAt(pt.x, pt.y);
      if (zone) onZone(zone);
    });
  }
  return root;
}

function toCourtPoint(root, e) {
  const rect = root.getBoundingClientRect();
  return {
    x: ((e.clientX - rect.left) / rect.width) * W,
    y: ((e.clientY - rect.top) / rect.height) * H,
  };
}

function heatColor(t) {
  // Von Blau ueber Cyan zu Orange – hoher Wert = warm.
  return t > 0.6 ? '#FF6B35' : t > 0.3 ? '#F59E0B' : '#22D3EE';
}

/**
 * Tor-Raster: sechs Tor-Zonen plus Daneben-Zonen.
 * opts.tallies  { zone: { goals, saved } }  (goals = Tore bzw. Gegentore, saved = Fehlwuerfe/Paraden)
 * opts.mode     'schuetze' (gruen = Tore) | 'torwart' (gruen = Paraden)
 */
export function goalGridEl({ selected = null, onZone, tallies = {}, mode = 'schuetze', disabled = false } = {}) {
  const max = Math.max(1, ...Object.values(tallies).map((t) => (t.goals ?? 0) + (t.saved ?? 0)));
  const cell = (zone, extraClass = '') => {
    const t = tallies[zone] ?? { goals: 0, saved: 0 };
    const total = (t.goals ?? 0) + (t.saved ?? 0);
    const intensity = total / max;
    const good = mode === 'torwart' ? t.saved : t.goals;
    const label = total
      ? (mode === 'torwart' ? `${t.saved ?? 0} P · ${t.goals ?? 0} GT` : `${t.goals ?? 0}/${total}`)
      : '';
    return h('button', {
      type: 'button',
      class: `goal-cell ${extraClass} ${selected === zone ? 'is-selected' : ''}`,
      dataset: { zone },
      disabled,
      style: { '--heat': total ? intensity.toFixed(2) : '0', '--good': good ? '1' : '0' },
      onclick: () => onZone?.(zone),
      attrs: { 'aria-label': `${GOAL_ZONE_LABELS[zone]} ${label}`.trim(), title: GOAL_ZONE_LABELS[zone] },
    },
      h('span', { class: 'goal-cell-name' }, GOAL_ZONE_LABELS[zone]),
      label ? h('span', { class: 'goal-cell-count' }, label) : null,
    );
  };
  const grid = h('div', { class: 'goal-grid' });
  grid.append(cell('drueber', 'span-all'));
  grid.append(cell('linksDaneben', 'side side-left'));
  for (const zone of ['obenLinks', 'obenMitte', 'obenRechts', 'untenLinks', 'untenMitte', 'untenRechts']) {
    grid.append(cell(zone, 'inner'));
  }
  grid.append(cell('rechtsDaneben', 'side side-right'));
  return grid;
}

