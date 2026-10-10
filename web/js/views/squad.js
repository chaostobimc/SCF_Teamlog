// Kader: Spieler anlegen, bearbeiten, loeschen, durchsuchen.
import { createPlayer, PLAYER_POSITIONS, PLAYER_ROLES, playerFullName } from '../model.js';
import { confirmDialog, downloadFile, h, openDialog, toast, toCsv } from '../ui.js';
import { emptyState, pageHead, positionTag, roleLabel, statCard } from '../components.js';
import { allTimeStatsForPlayer } from '../stats.js';

export function renderSquad({ store }) {
  const state = { filter: 'alle', query: '' };
  const listHost = h('div', { class: 'squad-grid' });
  const countHost = h('div', { class: 'kpi-grid compact' });

  const search = h('input', {
    class: 'input search', type: 'search', placeholder: 'Name oder Nummer …', 'aria-label': 'Kader durchsuchen',
    oninput: (e) => { state.query = e.target.value.trim().toLowerCase(); paint(); },
  });

  const chips = h('div', { class: 'chips', role: 'group', 'aria-label': 'Position filtern' },
    [['alle', 'Alle'], ['feldspieler', 'Feldspieler'], ['torwart', 'Torhüter']].map(([key, label]) => h('button', {
      class: 'chip', type: 'button', dataset: { filter: key },
      onclick: () => { state.filter = key; paint(); },
    }, label)),
  );

  const addBtn = h('button', { class: 'btn primary', type: 'button', onclick: () => editPlayer(null) }, '+ Spieler');

  function paint() {
    for (const chip of chips.querySelectorAll('.chip')) {
      const on = chip.dataset.filter === state.filter;
      chip.classList.toggle('is-active', on);
      chip.setAttribute('aria-pressed', String(on));
    }
    const all = [...store.team.players].sort((a, b) => a.number - b.number);
    const fieldCount = all.filter((p) => p.position === 'feldspieler').length;
    const keeperCount = all.length - fieldCount;
    countHost.replaceChildren(
      statCard({ label: 'Kader', value: all.length, sub: 'Spieler gesamt', icon: '👥' }),
      statCard({ label: 'Feldspieler', value: fieldCount, tone: 'accent', icon: '🤾' }),
      statCard({ label: 'Torhüter', value: keeperCount, tone: 'cyan', icon: '🧤' }),
    );

    const shown = all.filter((p) => {
      if (state.filter !== 'alle' && p.position !== state.filter) return false;
      if (!state.query) return true;
      return String(p.number).includes(state.query) || playerFullName(p).toLowerCase().includes(state.query);
    });

    listHost.replaceChildren(...(all.length === 0
      ? [emptyState({
          icon: '👥',
          title: 'Noch keine Spieler im Kader',
          text: 'Trikotnummer, Name, Position und Rolle hinzufügen – danach erscheint der Kader im Live-Spiel.',
          action: h('button', { class: 'btn primary', type: 'button', onclick: () => editPlayer(null) }, 'Ersten Spieler anlegen'),
        })]
      : shown.length === 0
        ? [h('p', { class: 'muted center' }, 'Keine Treffer.')]
        : shown.map((p) => playerCard(p))));
  }

  function playerCard(p) {
    const matches = store.matchesSorted();
    const s = allTimeStatsForPlayer(matches, p.id);
    const isKeeper = p.position === 'torwart';
    const main = isKeeper
      ? [h('span', {}, `${s.saves} Paraden`), h('span', {}, `${s.conceded} Gegentore`)]
      : [h('span', {}, `${s.goals} Tore`), h('span', {}, `${s.shots} Würfe`)];
    return h('article', { class: `player-card ${isKeeper ? 'is-keeper' : ''}` },
      h('button', {
        class: 'player-card-main', type: 'button', 'aria-label': `${playerFullName(p)} bearbeiten`,
        onclick: () => editPlayer(p),
      },
        h('div', { class: 'jersey' }, String(p.number)),
        h('div', { class: 'player-card-text' },
          h('div', { class: 'player-card-name' }, playerFullName(p)),
          h('div', { class: 'player-card-tags' },
            positionTag(p),
            p.gameRole !== 'keine' ? h('span', { class: 'tag' }, roleLabel(p.gameRole)) : null,
          ),
          h('div', { class: 'player-card-stats muted small' }, ...main),
        ),
      ),
      h('button', {
        class: 'icon-btn ghost-danger', type: 'button', title: 'Spieler löschen', 'aria-label': `${playerFullName(p)} löschen`,
        onclick: () => removePlayer(p),
      }, '🗑'),
    );
  }

  async function removePlayer(p) {
    const ok = await confirmDialog({
      title: `${playerFullName(p)} löschen?`,
      message: 'Der Spieler wird aus dem Kader entfernt. Vorhandene Spielstatistiken bleiben erhalten.',
    });
    if (!ok) return;
    store.deletePlayer(p.id);
    toast(`${playerFullName(p)} entfernt`);
    paint();
  }

  function editPlayer(player) {
    const isNew = !player;
    const numberInput = h('input', { class: 'input', type: 'number', min: 1, max: 99, required: true, value: player?.number ?? nextFreeNumber(), name: 'number', inputmode: 'numeric' });
    const firstInput = h('input', { class: 'input', name: 'firstName', value: player?.firstName ?? '', placeholder: 'Vorname', autocomplete: 'off' });
    const lastInput = h('input', { class: 'input', name: 'lastName', value: player?.lastName ?? '', placeholder: 'Nachname', autocomplete: 'off' });
    const posSelect = h('select', { class: 'input', name: 'position' },
      Object.entries(PLAYER_POSITIONS).map(([k, v]) => h('option', { value: k, selected: (player?.position ?? 'feldspieler') === k }, v)));
    const roleSelect = h('select', { class: 'input', name: 'gameRole' },
      Object.entries(PLAYER_ROLES).map(([k, v]) => h('option', { value: k, selected: (player?.gameRole ?? 'keine') === k }, v)));
    const errorBox = h('p', { class: 'form-error', role: 'alert' });

    return openDialog({
      title: isNew ? 'Neuer Spieler' : `${playerFullName(player)} bearbeiten`,
      submitLabel: isNew ? 'Hinzufügen' : 'Speichern',
      body: h('div', { class: 'form-grid' },
        h('label', { class: 'field' }, h('span', {}, 'Trikotnummer'), numberInput),
        h('label', { class: 'field' }, h('span', {}, 'Position'), posSelect),
        h('label', { class: 'field' }, h('span', {}, 'Vorname'), firstInput),
        h('label', { class: 'field' }, h('span', {}, 'Nachname'), lastInput),
        h('label', { class: 'field span-2' }, h('span', {}, 'Spielrolle'), roleSelect),
        errorBox,
        !isNew ? h('p', { class: 'muted small span-2' }, 'Änderungen wirken sofort auf Live-Spiel und Statistiken.') : null,
      ),
      onSubmit: () => {
        const number = Number(numberInput.value);
        if (!Number.isInteger(number) || number < 1 || number > 99) {
          errorBox.textContent = 'Trikotnummer muss zwischen 1 und 99 liegen.';
          numberInput.focus();
          return false;
        }
        const clash = store.team.players.find((p) => p.number === number && p.id !== player?.id);
        if (clash) {
          errorBox.textContent = `Nummer ${number} ist bereits an ${playerFullName(clash)} vergeben.`;
          numberInput.focus();
          return false;
        }
        if (!firstInput.value.trim() && !lastInput.value.trim()) {
          errorBox.textContent = 'Bitte mindestens Vor- oder Nachnamen eintragen.';
          firstInput.focus();
          return false;
        }
        const saved = createPlayer({
          id: player?.id,
          number,
          firstName: firstInput.value,
          lastName: lastInput.value,
          position: posSelect.value,
          gameRole: roleSelect.value,
        });
        store.upsertPlayer(saved);
        toast(isNew ? `${playerFullName(saved)} hinzugefügt` : 'Gespeichert');
        paint();
        return true;
      },
    });
  }

  function nextFreeNumber() {
    const used = new Set(store.team.players.map((p) => p.number));
    for (let n = 1; n <= 99; n++) if (!used.has(n)) return n;
    return 1;
  }

  const exportBtn = h('button', {
    class: 'btn ghost', type: 'button',
    onclick: () => {
      const rows = [['Nummer', 'Vorname', 'Nachname', 'Position', 'Spielrolle']];
      for (const p of [...store.team.players].sort((a, b) => a.number - b.number)) {
        rows.push([p.number, p.firstName, p.lastName, PLAYER_POSITIONS[p.position], PLAYER_ROLES[p.gameRole]]);
      }
      downloadFile('SCF_Kader.csv', toCsv(rows), 'text/csv;charset=utf-8');
    },
  }, 'Kader als CSV');

  paint();

  return h('div', { class: 'page' },
    pageHead({
      eyebrow: 'Mannschaft',
      title: 'Kader',
      subtitle: 'Trikotnummer, Name, Position und Spielrolle – wirkt sofort auf Aufgebot, Live-Spiel und Statistik.',
      actions: [exportBtn, addBtn],
    }),
    countHost,
    h('div', { class: 'toolbar' }, chips, search),
    listHost,
  );
}
