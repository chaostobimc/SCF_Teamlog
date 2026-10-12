// Rollen und Berechtigungen (Anzeige). Der Server prueft die Rechte; die Oberflaeche blendet nur aus.
export const ROLE_LABELS = { spieler: 'Spieler', trainer: 'Trainer', admin: 'Admin' };
export const ROLE_RANK = { spieler: 0, trainer: 1, admin: 2 };
export const ROLE_HELP = {
  spieler: 'Kann alles ansehen, aber nichts bearbeiten.',
  trainer: 'Kann alles ansehen und bearbeiten (Spiele, Kader, Live-Erfassung, Daten).',
  admin: 'Alles wie Trainer, dazu Konten verwalten, Passwörter zurücksetzen und Datenbank-Zugriff.',
};
