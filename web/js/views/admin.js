// Admin-Panel: Konten anlegen, Rollen aendern, Passwoerter zuruecksetzen, Datenbankzugriff.
import { api, ApiError } from '../api.js';
import { pageHead } from '../components.js';
import { confirmDialog, downloadFile, h, openDialog, toast } from '../ui.js';
import { ROLE_HELP, ROLE_LABELS } from './roles.js';

export function renderAdmin({ session, store }) {
  const usersBox = h('div', { class: 'table-wrap' }, h('p', { class: 'muted' }, 'Lade Konten …'));
  const formError = h('p', { class: 'form-error', role: 'alert' });

  const username = h('input', { class: 'input', name: 'username', required: true, minLength: 3, maxLength: 32, autocapitalize: 'off', spellcheck: false, placeholder: 'z. B. lena.m' });
  const displayName = h('input', { class: 'input', name: 'displayName', placeholder: 'z. B. Lena Müller' });
  const role = roleSelect('spieler');
  const password = h('input', { class: 'input', type: 'text', name: 'password', placeholder: 'leer = Einmal-Passwort wird erzeugt', autocomplete: 'off' });

  const createForm = h('form', {
    class: 'admin-create',
    onsubmit: async (e) => {
      e.preventDefault();
      formError.textContent = '';
      try {
        const res = await api('/admin/users', {
          method: 'POST',
          body: { username: username.value.trim(), displayName: displayName.value.trim(), role: role.value, password: password.value || undefined },
        });
        toast(`Konto ${res.user.username} angelegt`);
        if (res.temporaryPassword) showTemporary(res.user.displayName, res.user.username, res.temporaryPassword);
        createForm.reset();
        role.value = 'spieler';
        await load();
      } catch (err) {
        formError.textContent = err.message;
      }
    },
  },
    h('div', { class: 'grid-form' },
      h('label', { class: 'field' }, h('span', {}, 'Benutzername'), username),
      h('label', { class: 'field' }, h('span', {}, 'Anzeigename'), displayName),
      h('label', { class: 'field' }, h('span', {}, 'Rolle'), role),
      h('label', { class: 'field' }, h('span', {}, 'Passwort (optional)'), password),
    ),
    formError,
    h('div', { class: 'btn-row' }, h('button', { class: 'btn primary', type: 'submit' }, 'Konto anlegen')),
  );

  async function load() {
    try {
      const { users } = await api('/admin/users');
      usersBox.replaceChildren(usersTable(users));
    } catch (err) {
      usersBox.replaceChildren(h('p', { class: 'form-error' }, err.message));
    }
  }

  function usersTable(users) {
    return h('table', { class: 'data-table' },
      h('thead', {}, h('tr', {}, ...['Name', 'Benutzername', 'Rolle', 'Passwort', ''].map((t) => h('th', {}, t)))),
      h('tbody', {}, users.map((u) => h('tr', {},
        h('td', {}, u.displayName, u.id === session.user.id ? h('span', { class: 'muted small' }, ' (du)') : null),
        h('td', {}, u.username),
        h('td', {}, roleSelect(u.role, async (newRole) => {
          try {
            await api(`/admin/users/${u.id}`, { method: 'PATCH', body: { role: newRole } });
            toast('Rolle geändert');
            await load();
          } catch (err) {
            toast(err.message);
            await load();
          }
        })),
        h('td', {}, u.mustChange ? h('span', { class: 'pill warn' }, 'wechseln erforderlich') : h('span', { class: 'muted small' }, 'ok')),
        h('td', { class: 'row-actions' },
          h('button', { class: 'btn ghost sm', type: 'button', onclick: () => resetPassword(u) }, 'Passwort zurücksetzen'),
          u.id === session.user.id ? null : h('button', { class: 'btn ghost sm danger', type: 'button', onclick: () => removeUser(u) }, 'Löschen'),
        ),
      ))),
    );
  }

  async function resetPassword(u) {
    const ok = await confirmDialog({
      title: 'Passwort zurücksetzen?',
      message: `${u.displayName} (${u.username}) wird abgemeldet und muss beim nächsten Login ein eigenes Passwort setzen.`,
      confirmLabel: 'Zurücksetzen',
      danger: false,
    });
    if (!ok) return;
    try {
      const res = await api(`/admin/users/${u.id}/reset`, { method: 'POST' });
      showTemporary(u.displayName, u.username, res.temporaryPassword);
      await load();
    } catch (err) {
      toast(err.message);
    }
  }

  async function removeUser(u) {
    const ok = await confirmDialog({
      title: 'Konto löschen?',
      message: `${u.displayName} (${u.username}) wird gelöscht. Die Spiele und der Kader bleiben erhalten.`,
    });
    if (!ok) return;
    try {
      await api(`/admin/users/${u.id}`, { method: 'DELETE' });
      toast('Konto gelöscht');
      await load();
    } catch (err) {
      toast(err.message);
    }
  }

  async function exportJson() {
    try {
      const res = await fetch(new URL('api/admin/export', document.baseURI), { credentials: 'same-origin' });
      if (!res.ok) throw new ApiError(res.status, 'Export fehlgeschlagen.');
      downloadFile(`SCF_Teamlog_Export_${new Date().toISOString().slice(0, 10)}.json`, await res.text(), 'application/json');
      toast('Export heruntergeladen');
    } catch (err) {
      toast(err.message);
    }
  }

  const dbLink = h('a', {
    class: 'btn ghost',
    href: new URL('api/admin/db-file', document.baseURI).pathname,
    download: '',
  }, 'Datenbank-Datei (SQLite) laden');

  const node = h('div', { class: 'page' },
    pageHead({
      eyebrow: 'Administration',
      title: 'Admin-Panel',
      subtitle: 'Konten, Rollen und Datenbank. Der Server prüft alle Rechte.',
    }),
    h('section', { class: 'card' },
      h('div', { class: 'card-head' }, h('h2', {}, 'Konten'), h('span', { class: 'muted small' }, 'Rollen: ' + Object.values(ROLE_LABELS).join(' · '))),
      usersBox,
    ),
    h('section', { class: 'card' },
      h('div', { class: 'card-head' }, h('h2', {}, 'Neues Konto')),
      h('ul', { class: 'role-help muted small' }, Object.entries(ROLE_HELP).map(([k, v]) => h('li', {}, h('strong', {}, ROLE_LABELS[k] + ': '), v))),
      createForm,
    ),
    h('section', { class: 'card' },
      h('div', { class: 'card-head' }, h('h2', {}, 'Datenbank')),
      h('p', { class: 'muted' }, 'Vollzugriff: komplette Datenbank als SQLite-Datei oder alle Daten als JSON exportieren. Import eines JSON-Stands über „Daten & Sicherung“.'),
      h('div', { class: 'btn-row' },
        dbLink,
        h('button', { class: 'btn ghost', type: 'button', onclick: exportJson }, 'Export als JSON'),
      ),
    ),
  );

  load();
  return node;
}

function roleSelect(value, onChange = null) {
  return h('select', {
    class: 'input',
    onchange: onChange ? (e) => onChange(e.target.value) : null,
    'aria-label': 'Rolle',
  }, Object.entries(ROLE_LABELS).map(([k, label]) => h('option', { value: k, selected: k === value }, label)));
}

function showTemporary(name, username, password) {
  openDialog({
    title: 'Einmal-Passwort',
    hideSubmit: true,
    body: h('div', { class: 'stack' },
      h('p', {}, `${name} (${username}) meldet sich mit diesem Passwort an und setzt danach ein eigenes:`),
      h('code', { class: 'temp-pw' }, password),
      h('p', { class: 'muted small' }, 'Das Passwort wird nur jetzt angezeigt. Bitte sicher weitergeben.'),
    ),
  });
}
