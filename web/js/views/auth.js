// Anmeldung (inkl. Ersteinrichtung des ersten Admins) und Konto-Seite (Passwort aendern, Abmelden).
import { api } from '../api.js';
import { pageHead } from '../components.js';
import { h, toast } from '../ui.js';
import { ROLE_LABELS } from './roles.js';

export function renderLogin({ setupNeeded, onLoggedIn }) {
  const error = h('p', { class: 'form-error', role: 'alert' });
  const submit = h('button', { class: 'btn primary xl', type: 'submit' }, setupNeeded ? 'Admin-Konto anlegen' : 'Anmelden');
  let displayName = null;
  const username = h('input', { class: 'input', name: 'username', autocomplete: 'username', required: true, minLength: 3, maxLength: 32, autocapitalize: 'off', spellcheck: false });
  const password = h('input', { class: 'input', type: 'password', name: 'password', autocomplete: setupNeeded ? 'new-password' : 'current-password', required: true, minLength: 8 });
  const fields = [
    h('label', { class: 'field' }, h('span', {}, 'Benutzername'), username),
    h('label', { class: 'field' }, h('span', {}, setupNeeded ? 'Passwort (mind. 8 Zeichen)' : 'Passwort'), password),
  ];
  if (setupNeeded) {
    displayName = h('input', { class: 'input', name: 'displayName', placeholder: 'z. B. Max Mustermann', autocomplete: 'name' });
    fields.unshift(h('label', { class: 'field' }, h('span', {}, 'Anzeigename'), displayName));
  }

  const form = h('form', {
    class: 'login-form',
    onsubmit: async (e) => {
      e.preventDefault();
      error.textContent = '';
      submit.disabled = true;
      try {
        const body = { username: username.value.trim(), password: password.value };
        if (setupNeeded) body.displayName = displayName.value.trim();
        const res = await api(setupNeeded ? '/setup' : '/login', { method: 'POST', body });
        onLoggedIn(res.user);
      } catch (err) {
        error.textContent = err.message;
        submit.disabled = false;
      }
    },
  }, ...fields, error, submit);

  return h('section', { class: 'login-page' },
    h('div', { class: 'login-card card' },
      h('img', { class: 'login-logo', src: 'img/logo.png?v=8', alt: 'SC Freising Logo' }),
      h('h1', { class: 'login-title' }, 'SCF Teamlog'),
      h('p', { class: 'muted login-lead' }, setupNeeded
        ? 'Ersteinrichtung: Lege das Admin-Konto an. Der Admin legt danach alle weiteren Konten an.'
        : 'Bitte melde dich an, um den Teamstand zu sehen.'),
      form,
    ),
  );
}

export function renderAccount({ session, onLogout }) {
  const user = session.user;
  const current = h('input', { class: 'input', type: 'password', autocomplete: 'current-password', required: true });
  const next = h('input', { class: 'input', type: 'password', autocomplete: 'new-password', required: true, minLength: 8 });
  const repeat = h('input', { class: 'input', type: 'password', autocomplete: 'new-password', required: true, minLength: 8 });
  const error = h('p', { class: 'form-error', role: 'alert' });

  const pwForm = h('form', {
    class: 'stack-form',
    onsubmit: async (e) => {
      e.preventDefault();
      error.textContent = '';
      if (next.value !== repeat.value) {
        error.textContent = 'Die neuen Passwörter stimmen nicht überein.';
        return;
      }
      try {
        await api('/me/password', { method: 'POST', body: { current: current.value, newPassword: next.value } });
        toast('Passwort geändert');
        session.setUser({ ...user, mustChange: false });
        location.hash = '#/';
      } catch (err) {
        error.textContent = err.message;
      }
    },
  },
    h('label', { class: 'field' }, h('span', {}, 'Aktuelles Passwort'), current),
    h('label', { class: 'field' }, h('span', {}, 'Neues Passwort (mind. 8 Zeichen)'), next),
    h('label', { class: 'field' }, h('span', {}, 'Neues Passwort wiederholen'), repeat),
    error,
    h('div', { class: 'btn-row' }, h('button', { class: 'btn primary', type: 'submit' }, 'Passwort ändern')),
  );

  return h('div', { class: 'page' },
    pageHead({ eyebrow: 'Konto', title: user.displayName, subtitle: `Angemeldet als ${user.username} · ${ROLE_LABELS[user.role]}` }),
    user.mustChange
      ? h('div', { class: 'notice warn' }, 'Dein Passwort wurde zurückgesetzt. Bitte jetzt ein eigenes Passwort setzen.')
      : null,
    h('section', { class: 'card' },
      h('div', { class: 'card-head' }, h('h2', {}, 'Passwort ändern')),
      pwForm,
    ),
    h('section', { class: 'card' },
      h('div', { class: 'card-head' }, h('h2', {}, 'Sitzung')),
      h('p', { class: 'muted' }, 'Auf diesem Gerät abmelden. Lokal gespeicherte Kopien werden entfernt, die Daten bleiben auf dem Server.'),
      h('div', { class: 'btn-row' }, h('button', { class: 'btn ghost', type: 'button', onclick: onLogout }, 'Abmelden')),
    ),
  );
}
