// Anfragen an den Server (/api). Relative Adressen, damit die App auch unter einem Unterpfad laeuft.
export class ApiError extends Error {
  constructor(status, message, data = {}) {
    super(message);
    this.status = status;
    this.data = data;
  }
}

export async function api(path, { method = 'GET', body } = {}) {
  const init = { method, credentials: 'same-origin', headers: {} };
  if (body !== undefined) {
    init.headers['Content-Type'] = 'application/json';
    init.body = JSON.stringify(body);
  }
  let res;
  try {
    res = await fetch(new URL('api' + path, document.baseURI), init);
  } catch {
    throw new ApiError(0, 'Keine Verbindung zum Server.');
  }
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new ApiError(res.status, data.error ?? `Fehler ${res.status}`, data);
  return data;
}

/** Schnittstelle fuer den Store (Teamstand). */
export const remoteState = {
  fetchState: () => api('/state'),
  pushState: (body) => api('/state', { method: 'PUT', body }),
};
