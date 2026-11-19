extends Node
## Communication avec la page hôte via postMessage (protocole du socle).
## Hôte → jeu : {type: config|pause|resume|audio_ended|stop, payload}
## Jeu → hôte : {type: ready|play_audio|stop_audio|event|session_end|error, ...}
## Sécurité : origine des messages entrants vérifiée contre config/allowed_origins.json,
## envoi ciblé sur l'origine hôte (jamais "*"), JSON construit par JSON.stringify.

signal config_received(payload: Dictionary)
signal config_error_received(code: String, retry: bool)
signal pause_requested
signal resume_requested
signal audio_ended(id: String)
signal stop_requested

const VERSION := "1.0.0"
const CONFIG_TIMEOUT_MS := 2000
# Contrat DPP v1.1.0 : au-delà de ce délai après ready SANS config ni config_error
# en iframe hôte, le jeu affiche l'écran d'erreur (l'hôte ne reste jamais silencieux).
const HOST_CONFIG_TIMEOUT_MS := 8000

var _allowed_origins: Array = []
var _host_origin: String = ""
var _js_on_message: JavaScriptObject = null
var _js_window: JavaScriptObject = null
var _message_queue: Array = []
var _in_web: bool = false
var _ready_sent: bool = false
var _last_config_ms: int = 0
var _has_host_parent: bool = false

func _ready() -> void:
	_allowed_origins = _load_allowed_origins()
	_in_web = OS.has_feature("web")
	_has_host_parent = _detect_host_parent()
	if _in_web:
		_setup_js()

# --- Initialisation JavaScript ---

func _setup_js() -> void:
	var win := JavaScriptBridge.get_interface("window")
	if win == null:
		return
	_js_window = win
	# Les messages destinés au jeu arrivent sur la FENÊTRE DU JEU (window), pas sur le parent :
	# addEventListener doit être posé ici, sinon l'écoute ne fonctionne qu'en top-level.
	var callback := JavaScriptBridge.create_callback(_on_js_message)
	_js_on_message = callback  # référence gardée : sinon collectée par le GC
	win.addEventListener("message", callback)

func _load_allowed_origins() -> Array:
	var file := FileAccess.open("res://config/allowed_origins.json", FileAccess.READ)
	if file == null:
		push_error("allowed_origins.json introuvable : tous les messages entrants seront ignorés.")
		return []
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed == null or not parsed.has("allowed_origins"):
		return []
	return parsed["allowed_origins"]

# --- Réception ---

func _on_js_message(args: Array) -> void:
	# args[0] = l'objet MessageEvent JavaScript
	if args.is_empty():
		return
	var ev: JavaScriptObject = args[0]
	if ev == null:
		return
	var origin: String = str(ev.origin)
	if not _allowed_origins.has(origin):
		push_warning("Message ignoré : origine non autorisée (%s)" % origin)
		_telemetry_reject(origin)
		return
	var raw = ev.data
	if raw == null:
		return
	var text := JSON.stringify(raw) if typeof(raw) in [TYPE_OBJECT, TYPE_DICTIONARY] else str(raw)
	var parsed = JSON.parse_string(text)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		return
	_message_queue.append([parsed, origin])

func _telemetry_reject(origin: String) -> void:
	if not _ready_sent:
		return
	var data := {"code": "origin_rejected"}
	# aucune donnée d'origine dans l'événement (privacy) : seul le comptage intéresse la plateforme
	send_event("bridge_message_rejected", data)

func _process(_delta: float) -> void:
	while not _message_queue.is_empty():
		var entry: Array = _message_queue.pop_front()
		_handle_message(entry[0], entry[1])

func _handle_message(msg: Dictionary, origin: String = "") -> void:
	var type := str(msg.get("type", ""))
	if origin != "" and origin != "null":
		_host_origin = origin  # l'origine de la hôte est celle d'où vient la config
	match type:
		"config":
			if _host_origin == "":
				_host_origin = _detect_host_origin()
			var payload = msg.get("payload", {})
			if typeof(payload) == TYPE_DICTIONARY:
				_last_config_ms = Time.get_ticks_msec()
				config_received.emit(payload)
		"config_error":
			# Contrat v1.1.0 : la plateforme n'a pas pu produire la config.
			var data: Dictionary = msg.get("data", {}) if typeof(msg.get("data", {})) == TYPE_DICTIONARY else {}
			var code := str(data.get("code", "config_provider_failed"))
			var retry := bool(data.get("retry", true))
			_last_config_ms = Time.get_ticks_msec()
			config_error_received.emit(code, retry)
		"pause":
			pause_requested.emit()
		"resume":
			resume_requested.emit()
		"audio_ended":
			var id := str(msg.get("id", ""))
			audio_ended.emit(id)
		"stop":
			stop_requested.emit()
		_:
			pass  # champ inconnu : ignoré silencieusement (protocole tolérant)

func _detect_host_origin() -> String:
	if _js_window == null:
		return ""
	# window.parent.location.origin est inaccessible en iframe cross-origin ou sandboxée :
	# on passe par eval JS avec try/catch pour éviter toute exception silencieuse côté WASM.
	var res = JavaScriptBridge.eval("(function(){ try { return window.parent.location.origin; } catch(e) { return \"\"; } })()", true)
	return str(res) if res != null else ""

# --- Envoi ---

func _post(message: Dictionary) -> void:
	if not _in_web or _js_window == null:
		return
	var json := JSON.stringify(message)
	var parent: JavaScriptObject = _js_window.parent
	var target: String = _host_origin
	var is_bare_ready: bool = str(message.get("type", "")) == "ready"
	if target == "" and is_bare_ready:
		# ready ne porte aucune donnée (type+version) : on l'annonce sans restriction d'origine
		# pour que la hôte puisse répondre ; tout message avec données reste ciblé (jamais "*").
		parent.postMessage(json, "*")
		return
	if target == "":
		target = _allowed_origins[0] if not _allowed_origins.is_empty() else ""
	if target == "":
		push_error("Impossible d'envoyer : aucune origine hôte connue.")
		return
	parent.postMessage(json, target)

func send_ready() -> void:
	if _ready_sent:
		return
	_ready_sent = true
	_post({"type": "ready", "version": VERSION})

## Contrat v1.1.0 : réémettre ready (bouton Réessayer après config_error).
func resend_ready() -> void:
	_ready_sent = false
	send_ready()

func has_host_parent() -> bool:
	return _has_host_parent

func _detect_host_parent() -> bool:
	if not _in_web:
		return false
	var res = JavaScriptBridge.eval("(function(){ try { return window.parent !== window; } catch(e) { return false; } })()", true)
	return bool(res) if res != null else false

func send_play_audio(id: String, url: String, kind: String) -> void:
	_post({"type": "play_audio", "id": id, "url": url, "kind": kind})

func send_stop_audio() -> void:
	_post({"type": "stop_audio"})

func send_event(name: String, data: Dictionary) -> void:
	var msg := {
		"type": "event",
		"name": name,
		"data": data,
		"seq": Telemetry.next_seq(),
		"t_ms": Time.get_ticks_msec(),
	}
	_post(msg)

func send_session_end(reason: String, active_ms: int, items_done: int) -> void:
	_post({
		"type": "session_end",
		"data": {"reason": reason, "active_ms": active_ms, "items_done": items_done},
	})

func send_error(code: String, message: String) -> void:
	_post({"type": "error", "data": {"code": code, "message": message}})

# --- Mode développement : repli fichier local UNIQUEMENT sans hôte ---

func wait_for_config_or_dev(dev_path: String) -> void:
	# Contrat v1.1.0 : en iframe hôte, JAMAIS de repli local — on attend
	# config ou config_error ; sans réponse au bout de HOST_CONFIG_TIMEOUT_MS,
	# l'écran d'erreur calme s'affiche (récupérable par un nouveau ready).
	# Le repli dev ne se déclenche qu'en exécution locale autonome
	# (window.parent === window), typiquement l'export web ouvert directement.
	if _has_host_parent:
		await _watch_host_silent(HOST_CONFIG_TIMEOUT_MS / 1000.0)
		return
	await get_tree().create_timer(CONFIG_TIMEOUT_MS / 1000.0).timeout
	if _last_config_ms > 0:
		return  # une configuration (hôte) est arrivée : pas de repli dev
	var file := FileAccess.open(dev_path, FileAccess.READ)
	if file == null:
		send_error("config_missing", "Aucune configuration reçue ni fichier dev trouvé : %s" % dev_path)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_host_origin = _detect_host_origin()
		config_received.emit(parsed)

## Watchdog contrat v1.1.0 : sans config ni config_error après le délai donné,
## le jeu signale lui-même l'hôte silencieux (écran d'erreur, récupérable).
func _watch_host_silent(timeout_s: float) -> void:
	await get_tree().create_timer(timeout_s).timeout
	if _last_config_ms > 0:
		return  # config ou config_error reçue : cycle de vie respecté
	config_error_received.emit("host_silent", true)

## Repli utilisé par les tests : charge directement une config sans passer par le délai de 2 s.
## Tests : simule un message hôte entrant (comme la réception postMessage).
func emit_host_message(msg: Dictionary) -> void:
	_message_queue.append([msg, _allowed_origins[0] if not _allowed_origins.is_empty() else ""])

func emit_config_now(payload: Dictionary) -> void:
	_last_config_ms = Time.get_ticks_msec()
	_handle_message({"type": "config", "payload": payload}, "")

func is_web() -> bool:
	return _in_web
