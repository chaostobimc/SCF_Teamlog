// Kleine DOM-Helfer ohne Framework: Elemente, SVG, Toasts, Dialoge, Downloads.

const SVG_NS = 'http://www.w3.org/2000/svg';

/**
 * h('button', { class: 'btn', onclick: fn, dataset: {...}, attrs: {...} }, ...children)
 * Kinder: Strings (als Text), Nodes, Arrays, null/false (werden ignoriert).
 */
export function h(tag, props = {}, ...children) {
  const el = document.createElement(tag);
  for (const [key, value] of Object.entries(props ?? {})) {
    if (value === null || value === undefined || value === false) continue;
    if (key === 'class') el.className = value;
    else if (key === 'style' && typeof value === 'object') Object.assign(el.style, value);
    else if (key === 'dataset') Object.assign(el.dataset, value);
    else if (key === 'attrs') for (const [a, v] of Object.entries(value)) el.setAttribute(a, v);
    else if (key.startsWith('on') && typeof value === 'function') {
      el.addEventListener(key.slice(2).toLowerCase(), value);
    } else if (key === 'value' || key === 'checked' || key === 'disabled') el[key] = value;
    else el.setAttribute(key, value === true ? '' : value);
  }
  appendChildren(el, children);
  return el;
}

function appendChildren(el, children) {
  for (const child of children.flat(Infinity)) {
    if (child === null || child === undefined || child === false) continue;
    el.append(child instanceof Node ? child : document.createTextNode(String(child)));
  }
}

/** SVG-Element erzeugen. */
export function svg(tag, attrs = {}, ...children) {
  const el = document.createElementNS(SVG_NS, tag);
  for (const [key, value] of Object.entries(attrs)) {
    if (value === null || value === undefined || value === false) continue;
    el.setAttribute(key, value === true ? '' : String(value));
  }
  for (const child of children.flat(Infinity)) {
    if (child) el.append(child);
  }
  return el;
}

export function clear(el) {
  el.replaceChildren();
  return el;
}

/**
 * Ersetzt die Kinder eines Elements. Anders als replaceChildren werden Arrays
 * geflacht und null/false/undefined ignoriert (sonst erscheint „null“ im Text).
 */
export function setChildren(el, ...items) {
  const nodes = items
    .flat(Infinity)
    .filter((x) => x !== null && x !== undefined && x !== false)
    .map((x) => (x instanceof Node ? x : document.createTextNode(String(x))));
  el.replaceChildren(...nodes);
  return el;
}

// ------------------------------------------------------------ Toasts

let toastHost = null;

export function toast(message, { action = null, duration = 2600 } = {}) {
  if (!toastHost) {
    toastHost = h('div', { class: 'toast-host', attrs: { role: 'status', 'aria-live': 'polite' } });
    document.body.append(toastHost);
  }
  const node = h('div', { class: 'toast' },
    h('span', {}, message),
    action ? h('button', { class: 'toast-action', onclick: () => { action.onClick(); node.remove(); } }, action.label) : null,
  );
  toastHost.append(node);
  setTimeout(() => node.classList.add('toast-out'), duration);
  setTimeout(() => node.remove(), duration + 300);
}

// ------------------------------------------------------------ Dialoge

/**
 * Modaler Dialog. Gibt ein Promise zurueck, das mit dem Ergebnis von
 * `submit` aufgeloest wird (oder null beim Abbrechen).
 */
export function openDialog({ title, body, submitLabel = 'Speichern', danger = false, onSubmit, hideSubmit = false }) {
  return new Promise((resolve) => {
    const previous = document.activeElement;
    const close = (result) => {
      overlay.remove();
      document.removeEventListener('keydown', onKey);
      previous?.focus?.();
      resolve(result);
    };
    const onKey = (e) => {
      if (e.key === 'Escape') close(null);
    };
    const form = h('form', { class: 'dialog-form', onsubmit: (e) => {
      e.preventDefault();
      // onSubmit gibt false zurueck, wenn die Eingabe ungueltig ist (Dialog bleibt offen).
      const result = onSubmit ? onSubmit(form) : true;
      if (result === false) return;
      close(result === undefined ? true : result);
    } },
      h('header', { class: 'dialog-head' },
        h('h2', {}, title),
        h('button', { type: 'button', class: 'icon-btn', 'aria-label': 'Schließen', onclick: () => close(null) }, '✕'),
      ),
      h('div', { class: 'dialog-body' }, body),
      h('footer', { class: 'dialog-foot' },
        h('button', { type: 'button', class: 'btn ghost', onclick: () => close(null) }, 'Abbrechen'),
        hideSubmit ? null : h('button', { type: 'submit', class: danger ? 'btn danger' : 'btn primary' }, submitLabel),
      ),
    );
    const overlay = h('div', { class: 'overlay', onmousedown: (e) => { if (e.target === overlay) close(null); } }, h('div', { class: 'dialog', role: 'dialog', 'aria-modal': 'true' }, form));
    document.body.append(overlay);
    document.addEventListener('keydown', onKey);
    setTimeout(() => {
      const first = form.querySelector('input,select,textarea,button.primary,button.danger');
      first?.focus();
      if (first?.select && first.type !== 'date') first.select();
    }, 30);
  });
}

export function confirmDialog({ title, message, confirmLabel = 'Löschen', danger = true }) {
  return openDialog({
    title,
    body: h('p', { class: 'muted' }, message),
    submitLabel: confirmLabel,
    danger,
    onSubmit: () => true,
  }).then((result) => result === true);
}

// ------------------------------------------------------------ Downloads

export function downloadFile(filename, content, mime = 'text/plain;charset=utf-8') {
  const blob = content instanceof Blob ? content : new Blob([content], { type: mime });
  const url = URL.createObjectURL(blob);
  const a = h('a', { href: url, download: filename });
  document.body.append(a);
  a.click();
  setTimeout(() => {
    URL.revokeObjectURL(url);
    a.remove();
  }, 500);
}

/** CSV mit Semikolon (Excel-freundlich, deutsch) und BOM. */
export function toCsv(rows) {
  const esc = (v) => {
    const s = v === null || v === undefined ? '' : String(v);
    return /[";\n\r]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
  };
  return '\uFEFF' + rows.map((r) => r.map(esc).join(';')).join('\r\n') + '\r\n';
}

/** Dezimalzahl fuer CSV (Komma statt Punkt). */
export function csvPercent(ratio) {
  if (ratio === null || Number.isNaN(ratio)) return '';
  return String(Math.round(ratio * 1000) / 10).replace('.', ',');
}

export function sanitizeFilename(name) {
  return name.replace(/[^\w\-äöüÄÖÜß ]+/g, '').trim().replace(/\s+/g, '_');
}
