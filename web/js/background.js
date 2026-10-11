// Hintergrund der Oberflaeche: Auswahl in localStorage, angewendet auf <html data-bg>.
// "standard" ist der unveraenderte Hintergrund und setzt kein Attribut.
export const BACKGROUNDS = [
  { id: 'standard', label: 'Standard (hell)' },
  { id: 'feldlinien', label: 'Feldlinien' },
  { id: 'netz', label: 'Tornetz' },
  { id: 'verlauf', label: 'Abendverlauf' },
];
const KEY = 'scf-background';

export function getBackground() {
  const id = globalThis.localStorage?.getItem(KEY);
  return BACKGROUNDS.some((b) => b.id === id) ? id : 'standard';
}

export function applyBackground(id = getBackground()) {
  const root = document.documentElement;
  if (id === 'standard') delete root.dataset.bg;
  else root.dataset.bg = id;
}

export function setBackground(id) {
  if (!BACKGROUNDS.some((b) => b.id === id)) return;
  globalThis.localStorage?.setItem(KEY, id);
  applyBackground(id);
}
