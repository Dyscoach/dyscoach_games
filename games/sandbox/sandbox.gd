extends MiniGame
## Bac à sable : prouve que le socle fonctionne de bout en bout.
## Attend une configuration (host_test.html ou fichier dev), affiche l'état du socle,
## et permet de tester pause/resume/stop et l'écran d'erreur avec une config invalide.

var _status_label: Label = null
var _events_label: Label = null

func show_error_screen(code: String, message: String) -> void:
	Bridge.send_error(code, message)
	var overlay := ErrorScreen.build(message)
	add_child(overlay)

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = ThemeService.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 24)
	margin.add_child(vb)
	vb.add_child(UIKit.header(Strings.SANDBOX_TITLE, "Socle commun : pont, minuteur, audio, thème"))
	_status_label = Label.new()
	ThemeService.style_label(_status_label, Tuning.FONT_SIZE_BODY, ThemeService.INK)
	vb.add_child(_status_label)
	_events_label = Label.new()
	ThemeService.style_label(_events_label, int(Tuning.FONT_SIZE_BODY * 0.7), ThemeService.INK_SOFT)
	vb.add_child(_events_label)

	var test_invalid := UIKit.big_button("Tester une configuration invalide", _on_test_invalid)
	vb.add_child(test_invalid)
	var rest_btn := UIKit.big_button("Voir l'écran de repos", _on_show_rest)
	vb.add_child(rest_btn)

	Bridge.send_ready()
	Bridge.config_received.connect(_on_config)
	Bridge.pause_requested.connect(func() -> void: _set_status("Pause reçue (hôte)"))
	Bridge.resume_requested.connect(func() -> void: _set_status("Reprise reçue (hôte)"))
	Bridge.stop_requested.connect(func() -> void: _set_status("Stop reçu (hôte)"))
	# pas de config en 2 s → config de dev
	Bridge.wait_for_config_or_dev("res://dev/config_sandbox.json")
	_set_status("En attente de la configuration...")

func _on_config(payload: Dictionary) -> void:
	config = GameConfig.new(payload)
	if not config.validity:
		_set_status("Configuration invalide")
		show_error_screen("config_invalid", "; ".join(config.errors))
		return
	ThemeService.apply(config.raw)
	_set_status("Configuration %s reçue (jeu : %s, %d items, âge %s)" % [
		config.session_id, config.game_id, config.item_count(), config.age_band])

func _set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text
	var snap := Telemetry.log_snapshot()
	var lines: Array[String] = []
	for ev in snap.slice(maxi(snap.size() - 8, 0)):
		lines.append("%s %s" % [str(ev.get("name")), JSON.stringify(ev.get("data", {}))])
	_events_label.text = "\n".join(lines)

func _on_test_invalid() -> void:
	var bad := {"schema_version": 1, "session_id": "s_test", "game_id": "sandbox", "age_band": "99-99", "items": []}
	var cfg := GameConfig.new()
	cfg.parse(bad)
	if not cfg.validity:
		show_error_screen("config_invalid", "; ".join(cfg.errors))
		_set_status("Écran d'erreur affiché + événement error envoyé")

func _on_show_rest() -> void:
	var rest := RestScreen.build({"game_id": "sandbox"})
	add_child(rest)

