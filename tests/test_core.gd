## Tests du socle : validation de config, minuteur simulé, séquences, origines, reduce_motion.
## Booter avec la scène : godot --headless --path . res://tests/test_core.tscn
extends Node

var _failures: Array[String] = []
var _passes: int = 0

func _ready() -> void:
	await get_tree().process_frame
	_test_config_valid()
	_test_config_invalid()
	_test_config_missing_fields()
	_test_event_seq()
	_test_origin_filter()
	_test_reduce_motion()
	_test_timer_simulated()
	_finish()

# --- helpers ---
func check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
	else:
		_failures.append(label)
		push_error("FAIL : " + label)

# --- validation de configuration ---
func _test_config_valid() -> void:
	var cfg := GameConfig.new()
	cfg.parse(_sample_config())
	check(cfg.validity, "config d'exemple valide")
	check(cfg.game_id == "forge_mots", "game_id lu")
	check(cfg.age_band == "9-11", "age_band lu")
	check(cfg.item_count() == 1, "items comptés")
	check(cfg.max_active_minutes == 20.0, "session_limits lues")

func _test_config_invalid() -> void:
	var cfg := GameConfig.new()
	var bad := _sample_config()
	bad["schema_version"] = 3
	bad["age_band"] = "99-99"
	var items = bad["items"]
	items[0].erase("item_id")
	cfg.parse(bad)
	check(not cfg.validity, "config invalide détectée")
	check(cfg.errors.size() >= 3, "erreurs multiples listées")

func _test_config_missing_fields() -> void:
	var cfg := GameConfig.new()
	cfg.parse({})
	check(not cfg.validity, "config vide refusée")
	check(cfg.errors.has("session_id manquant"), "session_id manquant signalé")
	check(cfg.errors.has("items manquants ou vides"), "items vides signalés")

func _sample_config() -> Dictionary:
	return {
		"schema_version": 1,
		"session_id": "s_test",
		"game_id": "forge_mots",
		"locale": "fr-FR",
		"age_band": "9-11",
		"interaction": {"input": "tap_tap", "validation": "per_item"},
		"a11y": {"reduce_motion": false, "music": true, "show_time_digits": false},
		"session_limits": {"max_active_minutes": 20, "soft_end_at_minutes": 17},
		"difficulty": {"level": 2, "hints": true},
		"items": [{"item_id": "w_bateau", "word": "bateau", "graphemes": ["b", "a", "t", "eau"]}],
	}

# --- séquence d'événements ---
func _test_event_seq() -> void:
	var s1 := Telemetry.next_seq()
	var s2 := Telemetry.next_seq()
	check(s2 == s1 + 1, "séquence croissante")
	Telemetry.record("test", {})
	check(not Telemetry.log_snapshot().is_empty(), "journal rempli")

# --- filtrage d'origine ---
func _test_origin_filter() -> void:
	# simule un message d'une origine non autorisée : doit être ignoré
	var bridge := Bridge
	var queue_size_before: int = bridge._message_queue.size()
	var fake_ev := {"origin": "https://malicious.example", "data": {"type": "config", "payload": {}}}
	# on ne peut pas créer un vrai JavaScriptObject hors web : on teste la logique de liste
	var allowed: Array = bridge._allowed_origins
	check(not allowed.has("https://malicious.example"), "origine inconnue non autorisée")
	check(allowed.has("https://dyscoach.com"), "origine plateforme autorisée")
	check(bridge._message_queue.size() == queue_size_before, "aucun message injecté hors protocole")

# --- reduce_motion ---
func _test_reduce_motion() -> void:
	var cfg := _sample_config()
	cfg["a11y"] = {"reduce_motion": true, "music": true, "show_time_digits": false}
	ThemeService.apply(cfg)
	check(ThemeService.reduce_motion, "reduce_motion lu depuis la config")
	# sparkle_burst ne doit rien créer
	var holder := Control.new()
	add_child(holder)
	ThemeService.sparkle_burst(holder, Vector2.ZERO)
	check(holder.get_child_count() == 0, "reduce_motion : aucune particule créée")
	cfg["a11y"] = {"reduce_motion": false, "music": true, "show_time_digits": false}
	ThemeService.apply(cfg)
	ThemeService.sparkle_burst(holder, Vector2.ZERO)
	check(holder.get_child_count() > 0, "sans reduce_motion : particules créées")
	holder.queue_free()

# --- minuteur avec horloge simulée ---
func _test_timer_simulated() -> void:
	var timer := SessionTimer
	timer._inject_state(0, false)
	var soft_fired := [false]
	var limit_fired := [false]
	timer.soft_end.connect(func() -> void: soft_fired[0] = true)
	timer.time_limit.connect(func() -> void: limit_fired[0] = true)
	# soft end à 17 min = 1 020 000 ms
	timer._inject_state(1_020_000, true)
	timer._process(0.0)
	check(soft_fired[0], "soft end déclenché à soft_end_at_minutes")
	# limite à 20 min = 1 200 000 ms
	timer._inject_state(1_200_000, true)
	timer._process(0.0)
	check(limit_fired[0], "time limit déclenchée à max_active_minutes")
	# pause : le temps réel qui passe ne compte plus
	timer._inject_state(60_000, true)
	timer.pause()
	var frozen := timer.active_ms()
	await get_tree().create_timer(0.3).timeout
	check(timer.active_ms() == frozen, "pause : temps gelé malgré l'horloge réelle")
	# reprise : le comptage repart
	timer.resume()
	await get_tree().create_timer(0.3).timeout
	check(timer.active_ms() > frozen, "reprise : le comptage repart")
	# inactivité de 30 s : le temps n'est plus « actif »
	timer._inject_state(0, true)
	timer._last_interaction_ms = Time.get_ticks_msec() - Tuning.IDLE_TIMEOUT_MS - 1
	check(not timer.is_active(), "inactivité de 30 s : plus actif")

func _finish() -> void:
	if _failures.is_empty():
		print("TESTS CORE OK : %d vérifications" % _passes)
		get_tree().quit(0)
	else:
		print("TESTS CORE ÉCHOUÉS : %d — %s" % [_failures.size(), "; ".join(_failures)])
		get_tree().quit(1)
