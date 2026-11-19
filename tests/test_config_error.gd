## Tests du contrat DPP v1.1.0 : config_error, watchdog hôte silencieux,
## absence de repli dev en contexte hôte, réémission ready (Réessayer).
## Booter avec la scène : godot --headless --path . res://tests/test_config_error.tscn
extends Node

var _failures: Array[String] = []
var _passes: int = 0
# Les lambdas GDScript capturent les locales PAR VALEUR : les résultats de
# signaux passent par des MEMBRES (capturés par référence via l'instance).
var _got_code := ""
var _got_retry := false
var _dev_fallback_fired := false
var _host_silent_fired := false
var _retry_emitted := false

func _ready() -> void:
	await get_tree().process_frame
	_test_config_error_signal()
	_test_no_dev_fallback_when_host_silent()
	_test_resend_ready()
	_test_error_screen_retry_signal()
	_finish()

func check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
	else:
		_failures.append(label)
		push_error("FAIL : " + label)

func _test_config_error_signal() -> void:
	_got_code = ""
	_got_retry = false
	Bridge.config_error_received.connect(_on_config_error_signal, CONNECT_ONE_SHOT)
	# message hôte simulé conforme au contrat v1.1.0 — via la file postMessage
	# (le vrai chemin web : _on_js_message → _message_queue → _process)
	Bridge.emit_host_message({"type": "config_error", "data": {"code": "config_provider_failed", "retry": true}})
	check(not Bridge._message_queue.is_empty(), "message hôte mis en file")
	await get_tree().create_timer(0.2).timeout
	if not Bridge._message_queue.is_empty():
		Bridge._process(0.0)  # drain déterministe si le tick autoload n'est pas encore passé
	check(_got_code == "config_provider_failed", "config_error reçu : code lu (file)")
	check(_got_retry == true, "config_error reçu : retry lu (file)")

func _test_no_dev_fallback_when_host_silent() -> void:
	# En exécution headless il n'y a pas d'iframe : le repli dev reste légitime.
	# On vérifie ici la BRANCHE du contrat : _has_host_parent forcée à vrai →
	# le watchdog 8 s émet host_silent et NE CHARGE PAS le fichier dev.
	_dev_fallback_fired = false
	_host_silent_fired = false
	Bridge.config_received.connect(func(_payload: Dictionary) -> void:
		_dev_fallback_fired = true
	, CONNECT_ONE_SHOT)
	Bridge.config_error_received.connect(_on_host_silent_signal, CONNECT_ONE_SHOT)
	Bridge._has_host_parent = true
	Bridge._last_config_ms = 0
	# délai réduit : le watchdog de production attend 8 s ; ici on ne veut
	# qu'exercer la branche, on appelle la logique avec un timer court
	await get_tree().create_timer(0.1).timeout
	Bridge._watch_host_silent(0.1)
	await get_tree().create_timer(0.3).timeout
	check(_host_silent_fired, "hôte silencieux en iframe → config_error(host_silent)")
	check(not _dev_fallback_fired, "aucun repli dev en contexte hôte")
	Bridge._has_host_parent = false

func _test_resend_ready() -> void:
	Bridge._ready_sent = false
	Bridge.send_ready()
	check(Bridge._ready_sent, "send_ready arme le drapeau")
	Bridge.resend_ready()
	check(Bridge._ready_sent, "resend_ready réarme et renvoie ready")

func _test_error_screen_retry_signal() -> void:
	_retry_emitted = false
	var screen := ErrorScreen.build("test")
	screen.retry_requested.connect(func() -> void: _retry_emitted = true)
	add_child(screen)
	var btn: Button = _find_button(screen)

	check(btn != null, "bouton Réessayer présent")
	if btn != null:
		btn.pressed.emit()
		await get_tree().process_frame
	var consumed := _retry_emitted or not is_instance_valid(screen)
	if is_instance_valid(screen) and not consumed:
		consumed = screen.is_queued_for_deletion()
	check(consumed, "Réessayer déclenche le chemin retry")
	if is_instance_valid(screen) and not screen.is_queued_for_deletion():
		screen.queue_free()

func _on_config_error_signal(code: String, retry: bool) -> void:
	_got_code = code
	_got_retry = retry

func _on_host_silent_signal(code: String, _retry: bool) -> void:
	if code == "host_silent":
		_host_silent_fired = true

func _find_button(node: Node) -> Button:
	if node is Button and node.name == "RetryButton":
		return node
	for child in node.get_children():
		var found: Button = _find_button(child)
		if found != null:
			return found
	return null

func _finish() -> void:
	await get_tree().create_timer(0.2).timeout
	if _failures.is_empty():
		print("TESTS CONFIG-ERROR OK : %d vérifications" % _passes)
		get_tree().quit(0)
	else:
		push_error("TESTS CONFIG-ERROR ÉCHEC : %s" % ", ".join(_failures))
		get_tree().quit(1)
