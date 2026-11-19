/**
 * DysCoach Host — implémentation de référence côté plateforme (hôte).
 * Contrat : dpp/protocol.json v1.0.0. Aucune dépendance. ~200 lignes.
 *
 * L'équipe plateforme instancie DyscoachHost dans sa page (Next.js ou page de test),
 * lui passe son iframe et ses callbacks ; elle n'écrit JAMAIS de postMessage à la main.
 *
 *   const host = new DyscoachHost({
 *     iframe: document.getElementById("game-frame"),
 *     gameOrigin: "https://dyscoach.github.io",
 *     allowedOrigins: ["https://dyscoach.github.io"],
 *     onEvent: (name, data, msg) => console.log("event", name),  // journalisation / envoi serveur
 *     onSessionEnd: (data) => console.log("fin", data),          // fin de partie
 *     onError: (code, message) => console.warn(code),            // alerte interne
 *     audioUnlockOnFirstGesture: true                            // règles audio mobiles
 *   });
 *   host.loadGame();                     // charge l'iframe et attend ready
 *   host.sendConfig(myConfigObject);     // au ready (automatique si configProvider)
 *   host.pause(); host.resume(); host.stop();
 *
 * Garanties du contrat implémentées ici :
 * - vérification de l'origine de chaque message entrant (allowlist) ;
 * - envoi ciblé sur l'origine du jeu (jamais "*") ;
 * - play_audio via un élément <audio> + audio_ended, déverrouillage au premier geste ;
 * - pause/resume automatique quand l'onglet devient invisible ;
 * - journal complet des messages (dump() pour le débogage).
 */
"use strict";

export class DyscoachHost {
  constructor(options) {
    if (!options || !options.iframe) throw new Error("DyscoachHost: iframe requise");
    this.iframe = options.iframe;
    this.gameOrigin = options.gameOrigin || "";
    this.allowedOrigins = new Set(options.allowedOrigins || []);
    this.configProvider = options.configProvider || null; // () => Promise<config>
    this.onEvent = options.onEvent || (() => {});
    this.onSessionEnd = options.onSessionEnd || (() => {});
    this.onError = options.onError || (() => {});
    this.audioUnlockOnFirstGesture = options.audioUnlockOnFirstGesture !== false;
    this.protocol = 1;
    this._log = [];
    this._audioCache = new Map();
    this._audioUnlocked = false;
    this._startedAt = Date.now();
    this._configSent = false;
    this._handler = this._onMessage.bind(this);
    window.addEventListener("message", this._handler);
    this._bindVisibility();
    if (this.audioUnlockOnFirstGesture) {
      this._unlock = this._unlockAudio.bind(this);
      document.addEventListener("pointerdown", this._unlock, { once: true });
    }
  }

  // --- chargement du jeu ---

  loadGame(src) {
    const url = src || this.gameOrigin + "/index.html";
    this.iframe.src = url;
    return new Promise((resolve) => { this._resolveLoaded = resolve; });
  }

  // --- messages hôte → jeu ---

  sendConfig(config) {
    if (!config || config.schema_version !== 1) {
      throw new Error("DyscoachHost.sendConfig : configuration invalide (schema_version != 1)");
    }
    this._post({ type: "config", payload: config });
    this._configSent = true;
  }

  pause() { this._post({ type: "pause" }); }
  resume() { this._post({ type: "resume" }); }
  stop() { this._post({ type: "stop" }); }
  stopAudio() { this._stopAllAudio(); this._post({ type: "stop_audio" }); }

  // --- réception jeu → hôte ---

  _onMessage(ev) {
    if (ev.source !== this.iframe.contentWindow) return;
    if (!this.allowedOrigins.has(ev.origin)) {
      this._logEvent("origin_rejected", { origin: ev.origin });
      return;
    }
    let msg = ev.data;
    if (typeof msg === "string") {
      try { msg = JSON.parse(msg); } catch { return; }
    }
    if (!msg || typeof msg.type !== "string") return;
    this._log.push({ dir: "in", type: msg.type, msg, at: Date.now() - this._startedAt });
    switch (msg.type) {
      case "ready":
        this._ready = true;
        if (this.configProvider && !this._configSent) {
          Promise.resolve(this.configProvider()).then((cfg) => this.sendConfig(cfg));
        }
        if (this._resolveLoaded) { this._resolveLoaded(); this._resolveLoaded = null; }
        break;
      case "play_audio":
        this._playAudio(msg.id, msg.url, msg.kind);
        break;
      case "stop_audio":
        this._stopAllAudio();
        break;
      case "event":
        if (msg.name) this.onEvent(msg.name, msg.data || {}, msg);
        break;
      case "session_end":
        this.onSessionEnd(msg.data || {});
        break;
      case "error":
        this.onError(msg.data ? msg.data.code : "unknown", msg.data ? msg.data.message : "");
        break;
      default:
        break; // type inconnu : ignoré (tolérant, cf. contrat)
    }
  }

  _post(msg) {
    const win = this.iframe.contentWindow;
    if (!win || !this.gameOrigin) {
      // L'iframe peut être démontée (sortie du mode jeu) pendant qu'un timer
      // audio ou un visibilitychange déclenche encore pause/resume/stop :
      // environnement mort, on jette proprement le message au lieu de crasher
      // la page hôte (« jeu non chargé » inutile hors débogage).
      this._log.push({ dir: "dropped", type: msg.type, msg, at: Date.now() - this._startedAt });
      return;
    }
    win.postMessage(msg, this.gameOrigin);
    this._log.push({ dir: "out", type: msg.type, msg, at: Date.now() - this._startedAt });
  }

  // --- audio (déverrouillage mobile inclus) ---

  _unlockAudio() {
    if (this._audioUnlocked) return;
    this._audioUnlocked = true;
    try {
      const Ctx = window.AudioContext || window.webkitAudioContext;
      if (Ctx) { const ctx = new Ctx(); ctx.resume().catch(() => {}); }
    } catch { /* l'élément <audio> fonctionne aussi sans AudioContext */ }
  }

  _playAudio(id, url, kind) {
    if (this._audioCache.has(id)) { this._audioCache.get(id).pause(); }
    const audio = new Audio(url);
    this._audioCache.set(id, audio);
    audio.addEventListener("ended", () => {
      this._post({ type: "audio_ended", id });
      this._audioCache.delete(id);
    });
    audio.addEventListener("error", () => {
      // conformité : le jeu continue, il gère lui-même audio_missing côté plateforme
      this._post({ type: "audio_ended", id });
      this._audioCache.delete(id);
    });
    const p = audio.play();
    if (p && p.catch) {
      p.catch(() => {
        // play refusé (pas encore déverrouillé) : accusé immédiat pour ne pas bloquer le jeu
        this._post({ type: "audio_ended", id });
      });
    }
  }

  _stopAllAudio() {
    for (const audio of this._audioCache.values()) audio.pause();
    this._audioCache.clear();
  }

  // --- visibilité : pause automatique (le temps actif ne compte pas en onglet caché) ---

  _bindVisibility() {
    this._visibilityHandler = () => {
      if (document.hidden) this.pause();
      else this.resume();
    };
    document.addEventListener("visibilitychange", this._visibilityHandler);
  }

  // --- débogage ---

  dump() { return JSON.parse(JSON.stringify(this._log)); }
  _logEvent(name, data) { this._log.push({ dir: "internal", type: name, data, at: Date.now() - this._startedAt }); }

  destroy() {
    window.removeEventListener("message", this._handler);
    if (this._visibilityHandler) {
      document.removeEventListener("visibilitychange", this._visibilityHandler);
      this._visibilityHandler = null;
    }
    this._stopAllAudio();
    // L'iframe va être démontée : plus aucun message ne doit partir après destroy.
    this.gameOrigin = "";
    this._configSent = true;
  }
}

/** Validation minimale côté plateforme (miroir du validateur GameConfig du jeu). */
export function validateConfig(config) {
  const errors = [];
  if (config.schema_version !== 1) errors.push("schema_version doit valoir 1");
  if (!config.session_id) errors.push("session_id manquant");
  if (!config.game_id) errors.push("game_id manquant");
  if (!["6-8", "9-11", "12-14", "15-16"].includes(config.age_band)) errors.push("age_band invalide");
  if (!config.session_limits || !(config.session_limits.max_active_minutes > 0)) errors.push("session_limits invalide");
  if (!Array.isArray(config.items) || config.items.length === 0) errors.push("items vides");
  return { valid: errors.length === 0, errors };
}
