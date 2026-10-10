// Steuerung eines laufenden Spiels: Spieluhr, Halbzeiten, Ereignisse, Undo.
// Portiert aus lib/logic/match_controller.dart und match_state.dart.
import {
  createEvent,
  halfLengthSec,
  isGoalkeeperEvent,
  isOnTargetZone,
  matchClockSec,
  newId,
  phaseElapsedSec,
} from './model.js';

const HALF_LENGTH_BONUS_SEC = 5; // Wuerfe kurz nach Ablauf gelten noch
const AUTOSAVE_MS = 5000;
const TICK_MS = 200;

export class LiveSession {
  /**
   * @param {object} opts
   * @param {import('./model.js').Store} opts.store
   * @param {string} opts.matchId
   * @param {() => void} opts.onChange  Zustand hat sich geaendert (volles Neuzeichnen)
   * @param {() => void} opts.onTick    nur die Uhr hat sich bewegt
   */
  constructor({ store, matchId, onChange, onTick }) {
    this.store = store;
    this.onChange = onChange ?? (() => {});
    this.onTick = onTick ?? (() => {});
    const match = store.getMatch(matchId);
    if (!match) throw new Error('Spiel nicht gefunden');
    this.match = match;

    this.running = false;
    this.selectedPlayerId = null;
    this.pendingShot = null; // { goalZone, courtZone, isSevenMeter, isFreeThrow }
    this.lastCourtZone = null;
    this.opponentNumber = null;
    this.notice = null;
    this.noticeStamp = 0;

    this._timer = null;
    this._carryMs = 0;
    this._lastTs = 0;
    this._lastSave = 0;

    if (this.match.status === 'laufend' && this.match.phase !== 'beendet') {
      this._startTimer();
    }
  }

  get team() {
    return this.store.team;
  }

  get canRecord() {
    return this.match.status === 'laufend' && this.match.phase !== 'beendet';
  }

  dispose() {
    this._stopTimer();
  }

  // ------------------------------------------------------------ Uhr

  toggleClock() {
    const m = this.match;
    if (m.status === 'beendet' || m.phase === 'beendet') return;
    if (m.status !== 'laufend') {
      this._commit({ ...m, status: 'laufend' }, { keepClockRunning: true });
      this._startTimer();
      return;
    }
    if (this.running) this._pause();
    else this._startTimer();
  }

  _pause() {
    this._stopTimer();
    this.store.saveMatch(this.match);
    this.running = false;
    this._emit();
  }

  _startTimer() {
    this._stopTimer();
    this._carryMs = 0;
    this._lastTs = Date.now();
    this._lastSave = Date.now();
    this._timer = setInterval(() => this._tick(), TICK_MS);
    this.running = true;
    this._emit();
  }

  _stopTimer() {
    if (this._timer) clearInterval(this._timer);
    this._timer = null;
    this.running = false;
  }

  _tick() {
    const now = Date.now();
    this._carryMs += now - this._lastTs;
    this._lastTs = now;
    const seconds = Math.floor(this._carryMs / 1000);
    if (seconds <= 0) return;
    this._carryMs -= seconds * 1000;

    let m = this.match;
    if (m.status !== 'laufend' || m.phase === 'beendet') {
      this._stopTimer();
      this._emit();
      return;
    }

    switch (m.phase) {
      case 'ersteHalbzeit': {
        let elapsed = m.firstHalfSec + seconds;
        if (elapsed >= halfLengthSec(m)) {
          elapsed = halfLengthSec(m);
          m = { ...m, firstHalfSec: elapsed, phase: 'halbzeitpause' };
          this._stopTimer();
          this._commit(m, { keepClockRunning: false });
          this._notify('Ende der 1. Halbzeit');
          return;
        }
        m = { ...m, firstHalfSec: elapsed };
        break;
      }
      case 'halbzeitpause':
        m = { ...m, pauseSec: m.pauseSec + seconds };
        break;
      case 'zweiteHalbzeit': {
        let elapsed = m.secondHalfSec + seconds;
        if (elapsed >= halfLengthSec(m)) {
          elapsed = halfLengthSec(m);
          m = { ...m, secondHalfSec: elapsed, phase: 'beendet', status: 'beendet' };
          this._stopTimer();
          this._commit(m, { keepClockRunning: false });
          this._notify('Spielende');
          return;
        }
        m = { ...m, secondHalfSec: elapsed };
        break;
      }
      default:
        return;
    }

    this.match = m;
    if (now - this._lastSave >= AUTOSAVE_MS) {
      this._lastSave = now;
      this.store.saveMatch(m);
    }
    this.onTick();
  }

  /** Uebergang zur 2. Halbzeit (manuell, auch vor Ablauf der Zeit). */
  startSecondHalf() {
    const m = this.match;
    if (m.phase === 'beendet' || m.phase === 'zweiteHalbzeit') return;
    const wasRunning = this.running;
    this._stopTimer();
    this.pendingShot = null;
    this._commit({ ...m, phase: 'zweiteHalbzeit' }, { keepClockRunning: false });
    this._notify('2. Halbzeit');
    if (wasRunning) this._startTimer();
  }

  finishMatch() {
    const m = this.match;
    if (m.status === 'beendet') return;
    this._stopTimer();
    this._commit({ ...m, phase: 'beendet', status: 'beendet' }, { keepClockRunning: false });
    this._notify('Spiel beendet');
  }

  /** Auszeit: Uhr anhalten und melden. */
  timeout() {
    if (this.match.status !== 'laufend') return;
    if (this.running) this._pause();
    this._notify('Auszeit');
  }

  /** Spielzeit der aktuellen Phase um Delta Sekunden aendern. */
  adjustClock(delta) {
    this._setPhaseSec(phaseElapsedSec(this.match) + delta);
    this._notify(delta > 0 ? `+${delta} s` : `${delta} s`, false);
  }

  /** Spielzeit der aktuellen Phase exakt setzen. */
  setPeriodClock(seconds) {
    this._setPhaseSec(seconds);
  }

  _setPhaseSec(value) {
    const v = Math.max(0, Math.round(value));
    const m = this.match;
    let updated;
    switch (m.phase) {
      case 'ersteHalbzeit': updated = { ...m, firstHalfSec: v }; break;
      case 'zweiteHalbzeit': updated = { ...m, secondHalfSec: v }; break;
      default: updated = { ...m, pauseSec: v }; break;
    }
    this._commit(updated, { keepClockRunning: this.running });
  }

  // ------------------------------------------------- Spieler & Zonen

  selectPlayer(playerId) {
    const same = this.selectedPlayerId === playerId;
    this.selectedPlayerId = same ? null : playerId;
    this.pendingShot = null;
    this._emit();
  }

  get selectedPlayer() {
    if (!this.selectedPlayerId) return null;
    return this.team.players.find((p) => p.id === this.selectedPlayerId) ?? null;
  }

  get isKeeperSelected() {
    return this.selectedPlayer?.position === 'torwart';
  }

  /** Spieler des Aufgebots (leer = alle). */
  squadPlayers() {
    const ids = this.match.squadPlayerIds;
    const players = [...this.team.players].sort((a, b) => a.number - b.number);
    if (!ids.length) return players;
    return players.filter((p) => ids.includes(p.id));
  }

  /** Tor-Raster angetippt. */
  onGoalZoneTap(zone) {
    if (!this.canRecord) return;
    const player = this.selectedPlayer;
    if (!player) {
      this._notify('Erst Spieler auswählen');
      return;
    }
    if (isOnTargetZone(zone)) {
      this.pendingShot = {
        goalZone: zone,
        courtZone: this._contextCourtZone(),
        isSevenMeter: this.lastCourtZone === 'siebenMeter',
        isFreeThrow: this.lastCourtZone === 'freiwurf',
      };
      this._emit();
      return;
    }
    // Daneben / Latte: sofortiger Fehlwurf (nur Feldspieler).
    if (player.position === 'torwart') {
      this._notify('Daneben – keine Torhüter-Aktion');
      return;
    }
    this._record({
      playerId: player.id,
      type: 'fehlwurf',
      goalZone: zone,
      courtZone: this._contextCourtZone(),
      isSevenMeter: this.lastCourtZone === 'siebenMeter',
      isFreeThrow: this.lastCourtZone === 'freiwurf',
    });
  }

  /** Spielfeld angetippt: Zone merken bzw. laufenden Wurf ergaenzen. */
  onCourtZoneTap(zone) {
    if (!this.canRecord) return;
    if (zone === 'siebenMeter' || zone === 'freiwurf') {
      this.lastCourtZone = zone;
      if (this.pendingShot) {
        this.pendingShot = {
          goalZone: this.pendingShot.goalZone,
          courtZone: zone,
          isSevenMeter: zone === 'siebenMeter',
          isFreeThrow: zone === 'freiwurf',
        };
      }
      this._emit();
      return;
    }
    this.lastCourtZone = zone;
    // Laufender Wurf (z. B. Tor schon angetippt): Wurfposition nachtraeglich korrigieren.
    if (this.pendingShot) this.pendingShot = { ...this.pendingShot, courtZone: zone };
    this._emit();
  }

  /** Wurfkontext ohne Zone setzen (Chips). */
  setQuickContext(zone) {
    if (!zone) {
      this.lastCourtZone = null;
      this._emit();
      return;
    }
    this.onCourtZoneTap(zone);
  }

  setOpponentNumber(number) {
    const n = Number.parseInt(number, 10);
    this.opponentNumber = Number.isInteger(n) && n >= 1 && n <= 99 ? n : null;
    this._emit();
  }

  /** 7m / Freiwurf / Feld im laufenden Wurf umschalten. */
  setThrowContext({ sevenMeter, freeThrow }) {
    const p = this.pendingShot;
    if (!p) return;
    let courtZone = p.courtZone;
    if (sevenMeter === true) courtZone = 'siebenMeter';
    else if (freeThrow === true) courtZone = 'freiwurf';
    this.pendingShot = {
      goalZone: p.goalZone,
      courtZone,
      isSevenMeter: sevenMeter ?? p.isSevenMeter,
      isFreeThrow: freeThrow ?? p.isFreeThrow,
    };
    this._emit();
  }

  cancelPendingShot() {
    this.pendingShot = null;
    this._emit();
  }

  // ----------------------------------------------------- Ereignisse

  /** Ergebnis eines aufgeschluesselten Wurfs. */
  resolvePendingShot(outcome) {
    const pending = this.pendingShot;
    const player = this.selectedPlayer;
    if (!pending || !player || !this.canRecord) return;
    if (player.position === 'torwart') {
      const mapped = this._goalkeeperOutcome(outcome, pending);
      if (!mapped) {
        this._notify('Keine passende Torhüter-Aktion');
        return;
      }
      this._record({
        playerId: player.id,
        type: mapped,
        goalZone: pending.goalZone,
        courtZone: pending.courtZone,
        isSevenMeter: pending.isSevenMeter,
        isFreeThrow: pending.isFreeThrow,
        isOpponent: true,
      });
      return;
    }
    this._record({
      playerId: player.id,
      type: outcome,
      goalZone: pending.goalZone,
      courtZone: pending.courtZone,
      isSevenMeter: pending.isSevenMeter,
      isFreeThrow: pending.isFreeThrow,
    });
  }

  _goalkeeperOutcome(outcome, pending) {
    if (outcome === 'tor' || outcome === 'gegentor') {
      if (pending.isSevenMeter) return 'gegentorSiebenMeter';
      if (pending.isFreeThrow) return 'gegentorFreiwurf';
      return 'gegentor';
    }
    if (outcome === 'wurfGehalten' || outcome === 'parade') {
      if (pending.isSevenMeter) return 'paradeSiebenMeter';
      if (pending.isFreeThrow) return 'paradeFreiwurf';
      return 'parade';
    }
    return null;
  }

  /** Schnellaktion (Technik, Zweikampf, Sanktion ...). */
  commitQuickAction(type) {
    if (!this.canRecord) return;
    const player = this.selectedPlayer;
    if (!player) {
      this._notify('Erst Spieler auswählen');
      return;
    }
    const keeperEvent = isGoalkeeperEvent(type);
    if (keeperEvent && player.position !== 'torwart') {
      this._notify('Nur für Torhüter');
      return;
    }
    this._record({
      playerId: player.id,
      type,
      courtZone: keeperEvent ? this.lastCourtZone : this._contextCourtZone(),
      isSevenMeter: this.lastCourtZone === 'siebenMeter',
      isFreeThrow: this.lastCourtZone === 'freiwurf',
      isOpponent: keeperEvent,
    });
  }

  /** Gegnerwurf verfehlt bzw. geblockt (nur fuer das Wurfbild des Torwarts). */
  commitOpponentAction(type) {
    if (!this.canRecord) return;
    const player = this.selectedPlayer;
    if (!player || player.position !== 'torwart') {
      this._notify('Torhüter auswählen');
      return;
    }
    this._record({
      playerId: player.id,
      type,
      courtZone: this._contextCourtZone(),
      isSevenMeter: this.lastCourtZone === 'siebenMeter',
      isFreeThrow: this.lastCourtZone === 'freiwurf',
      isOpponent: true,
    });
  }

  undoLastEvent() {
    const events = this.match.events;
    if (!events.length) return;
    this._commit(
      { ...this.match, events: events.slice(0, -1) },
      { keepClockRunning: this.running },
    );
    this._notify('Aktion zurückgenommen');
  }

  removeEvent(eventId) {
    const events = this.match.events;
    if (!events.some((e) => e.id === eventId)) return;
    this._commit(
      { ...this.match, events: events.filter((e) => e.id !== eventId) },
      { keepClockRunning: this.running },
    );
    this._notify('Aktion gelöscht');
  }

  // ----------------------------------------------------------- intern

  _contextCourtZone() {
    const z = this.lastCourtZone;
    return z === 'siebenMeter' || z === 'freiwurf' ? null : z;
  }

  _record({ playerId, type, goalZone = null, courtZone = null, isSevenMeter = false, isFreeThrow = false, isOpponent = false }) {
    const m = this.match;
    const event = createEvent({
      id: newId(),
      playerId,
      type,
      matchClockSec: matchClockSec(m),
      phase: m.phase,
      isSevenMeter,
      isOpponent,
      opponentNumber: isOpponent ? this.opponentNumber : null,
      goalZone,
      courtZone,
      createdAt: Date.now(),
    });
    // Wurf-Kontext zuerst leeren, damit die Oberflaeche beim Speichern schon den neuen Zustand zeigt.
    this.pendingShot = null;
    this.lastCourtZone = null;
    this._commit({ ...m, events: [...m.events, event] }, { keepClockRunning: this.running });
  }

  /** Speichert das Spiel; schliesst Halbzeit-Toleranz ein. */
  _commit(match, { keepClockRunning = false } = {}) {
    let toSave = match;
    if (!keepClockRunning && toSave.phase !== 'beendet') {
      const over = phaseElapsedSec(toSave) - halfLengthSec(toSave);
      if (over > 0 && over <= HALF_LENGTH_BONUS_SEC) {
        if (toSave.phase === 'ersteHalbzeit') toSave = { ...toSave, firstHalfSec: halfLengthSec(toSave) };
        if (toSave.phase === 'zweiteHalbzeit') toSave = { ...toSave, secondHalfSec: halfLengthSec(toSave) };
      }
    }
    this.match = toSave;
    this.store.saveMatch(toSave);
    this._emit();
    return toSave;
  }

  _notify(message, emit = true) {
    this.notice = message;
    this.noticeStamp = Date.now();
    if (emit) this._emit();
    else this.onChange();
  }

  _emit() {
    this.onChange();
  }
}
