// Test du contrat dpp/protocol.json : cohérence entre les implémentations
// Exécuter : node dpp/test-protocol.mjs
import { readFileSync } from "node:fs";
import { validateConfig } from "./host/dyscoach-host.js";

let failures = 0;
function check(cond, label) {
  if (cond) console.log("  OK :", label);
  else { console.error("  FAIL:", label); failures++; }
}

const proto = JSON.parse(readFileSync(new URL("./protocol.json", import.meta.url), "utf8"));

console.log("— schéma du protocole —");
check(proto.protocol_name === "dyscoach-play", "nom du protocole");
check(proto.protocol_version === "1.1.0", "version 1.1.0");
check(typeof proto.invariants.one_session_end === "string", "invariant un seul session_end documenté");

console.log("— messages host_to_game —");
for (const t of ["config", "config_error", "pause", "resume", "audio_ended", "stop"]) {
  check(proto.messages_host_to_game[t] !== undefined, `message ${t} défini`);
}
check(proto.messages_host_to_game.config.required.includes("items"), "champs obligatoires de config documentés");
check(typeof proto.messages_host_to_game.config_error.payload.retry === "string", "config_error.retry documenté");
check(proto.messages_game_to_host.ready !== undefined && proto.lifecycle.order.includes("config | config_error"), "cycle de vie : chaque ready reçoit config ou config_error");
const ageBands = proto.messages_host_to_game.config.schema_config.age_band;
check(Array.isArray(ageBands) && ["6-8", "9-11", "12-14", "15-16"].every(b => ageBands.includes(b)), "tranches d'âge documentées");

console.log("— messages game_to_host —");
for (const t of ["ready", "play_audio", "stop_audio", "event", "session_end", "error"]) {
  check(proto.messages_game_to_host[t] !== undefined, `message ${t} défini`);
}
check(proto.messages_game_to_host.session_end.payload.reason.includes("time_limit"), "raisons de session_end documentées");

console.log("— catalogue des events —");
const events = proto.event_names.common;
for (const e of ["session_started", "item_presented", "item_answered", "item_completed", "hint_shown", "audio_replayed", "break_started", "session_ended"]) {
  check(events[e] !== undefined, `event ${e} défini`);
}
check(proto.event_names.sonimaux.creature_evolved !== undefined, "event creature_evolved (sonimaux) défini");

console.log("— detail item_answered par jeu —");
const games = ["forge_mots", "chasse_sons", "duo_mots", "memo_mots", "syllabo", "radar_lettres"];
for (const g of games) check(proto.item_answered_detail_by_game[g] !== undefined, `detail ${g} défini`);

console.log("— codes d'erreur —");
for (const c of ["audio_missing", "phoneme_audio_missing", "image_missing", "story_unchecked", "config_invalid"]) {
  check(proto.error_codes[c] !== undefined, `error ${c} défini`);
}

console.log("— implémentation hôte de référence —");
const hostSrc = readFileSync(new URL("./host/dyscoach-host.js", import.meta.url), "utf8");
check(hostSrc.includes("sendConfigError"), "hôte : sendConfigError défini");
check(hostSrc.includes(".catch((err) => this.sendConfigError"), "hôte : échec du configProvider signalé au jeu (pas de silence)");
check(hostSrc.includes("config_error"), "hôte : message config_error émis");
const ok = validateConfig({ schema_version: 1, session_id: "s1", game_id: "forge_mots", age_band: "9-11", session_limits: { max_active_minutes: 20 }, items: [{}] });
check(ok.valid, "validateConfig accepte une config valide");
const bad = validateConfig({ schema_version: 3, age_band: "99-99" });
check(!bad.valid && bad.errors.length >= 4, "validateConfig refuse une config invalide");

console.log("— cohérence avec le jeu Godot —");
const bridge = readFileSync(new URL("../core/bridge.gd", import.meta.url), "utf8");
for (const t of ["ready", "play_audio", "stop_audio", "event", "session_end", "error"]) {
  check(bridge.includes(`"${t}"`), `bridge.gd implémente ${t}`);
}
check(bridge.includes("config_error"), "bridge.gd implémente config_error (reçu de l'hôte)");
check(bridge.includes("resend_ready"), "bridge.gd réémet ready (Réessayer)");
check(bridge.includes("_has_host_parent") || bridge.includes("has_host_parent"), "bridge.gd distingue exécution locale / iframe hôte");
const main = readFileSync(new URL("../main/main.gd", import.meta.url), "utf8");
for (const g of games) check(main.includes(`"${g}"`), `main.gd enregistre le jeu ${g}`);

if (failures === 0) { console.log("\nPROTOCOLE DPP OK — toutes les vérifications passent"); process.exit(0); }
console.error(`\nPROTOCOLE DPP ÉCHOUÉ : ${failures}`);
process.exit(1);
