extends MiniGame
## Radar à Lettres (game_id : radar_lettres) — échauffement visuel, 1 à 2 minutes max.
## Trouver dans une grille toutes les lettres identiques à un modèle (mot-repère + son).
## Ce n'est présenté NI comme un traitement NI comme un exercice visuel thérapeutique.
## La grille est FOURNIE (ordre fixe) : le jeu ne la tire pas au hasard.
## Plafond : 2 minutes d'activité (Tuning.RADAR_SESSION_MAX_MS) puis fin propre.

var _items: Array = []
var _current_index: int = -1
var _current: Dictionary = {}
var _grid_cells: Array = []            # boutons de la grille
var _found_count: int = 0
var _confusions: Array = []            # {tapped, expected}
var _attempts: int = 0
var _item_start_ms: int = 0
var _session_deadline_ms: int = 0
var _main_vb: VBoxContainer = null
var _status: Label = null
var _model_label: Label = null
var _grid: GridContainer = null
var _speaker: Button = null
var _dots: ProgressDots = null
var _finished: bool = false

func _setup(cfg: GameConfig) -> void:
	var errs := GameConfig.validate_radar_items(cfg.items)
	if not errs.is_empty():
		show_error_screen("config_invalid", "; ".join(errs))
		return
	_items = cfg.items
	_session_deadline_ms = Time.get_ticks_msec() + Tuning.RADAR_SESSION_MAX_MS
	_build_ui()
	start()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = ThemeService.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 32)
	add_child(margin)
	_main_vb = VBoxContainer.new()
	_main_vb.add_theme_constant_override("separation", 18)
	margin.add_child(_main_vb)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	_main_vb.add_child(top)
	_speaker = UIKit.speaker_button(_on_replay_sound)
	top.add_child(_speaker)
	var title := Label.new()
	title.text = Strings.RADAR_TITLE
	ThemeService.style_label(title, Tuning.FONT_SIZE_TITLE, ThemeService.INK, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(title)
	top.add_child(build_time_gauge())

	# modèle + mot-repère (ex. « b comme bateau »)
	_model_label = Label.new()
	_model_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeService.style_label(_model_label, int(Tuning.FONT_SIZE_TITLE * 0.8), ThemeService.ACCENT, true)
	_main_vb.add_child(_model_label)

	# progression calme : une pastille par grille de la configuration
	var dots_wrap := CenterContainer.new()
	_dots = ProgressDots.new()
	_dots.setup(maxi(config.items.size(), 1))
	dots_wrap.add_child(_dots)
	_main_vb.add_child(dots_wrap)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeService.style_label(_status, Tuning.FONT_SIZE_BODY, ThemeService.INK)
	_main_vb.add_child(_status)

	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main_vb.add_child(center)
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", ThemeService.min_spacing())
	_grid.add_theme_constant_override("v_separation", ThemeService.min_spacing())
	center.add_child(_grid)

func on_start() -> void:
	_next_grid()

func _next_grid() -> void:
	if _finish_requested:
		return
	# plafond de 2 minutes : la séance s'arrête proprement
	if Time.get_ticks_msec() >= _session_deadline_ms:
		_finish_session_quietly()
		return
	_current_index += 1
	if _current_index >= _items.size():
		_finish_session_quietly()
		return
	_current = _items[_current_index]
	_found_count = 0
	_confusions.clear()
	_attempts = 0
	_item_start_ms = Time.get_ticks_msec()
	announce_item(str(_current.get("item_id", "")))
	var anchor := str(_current.get("anchor_word", ""))
	_model_label.text = Strings.RADAR_ANCHOR % [str(_current.get("target", "")), anchor]
	_build_grid()
	_play_sound()

func _build_grid() -> void:
	for c in _grid_cells:
		c.queue_free()
	_grid_cells.clear()
	var grid_data: Array = _current.get("grid", [])
	var cols := 3 if grid_data.size() <= 9 else 4
	_grid.columns = cols
	var cell := _cell_size(grid_data.size(), cols)
	for letter in grid_data:
		var btn := Button.new()
		btn.text = str(letter)
		btn.custom_minimum_size = Vector2(cell, cell)
		btn.add_theme_font_override("font", ThemeService.font_bold())
		btn.add_theme_font_size_override("font_size", Tuning.FONT_SIZE_GRID)
		btn.add_theme_color_override("font_color", ThemeService.INK)
		btn.add_theme_color_override("font_hover_color", ThemeService.INK)
		btn.add_theme_color_override("font_pressed_color", ThemeService.INK)
		btn.add_theme_color_override("font_focus_color", ThemeService.INK)
		btn.add_theme_color_override("font_disabled_color", ThemeService.INK)
		var sb := StyleBoxFlat.new()
		sb.bg_color = ThemeService.SURFACE
		sb.border_color = ThemeService.BORDER
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(int(Tuning.UI_CORNER_RADIUS_SMALL))
		btn.add_theme_stylebox_override("normal", sb)
		var hover := sb.duplicate()
		hover.bg_color = ThemeService.ACCENT_SOFT
		btn.add_theme_stylebox_override("hover", hover)
		btn.add_theme_stylebox_override("pressed", sb)
		btn.pressed.connect(_on_cell_pressed.bind(btn))
		_grid.add_child(btn)
		_grid_cells.append(btn)

func _cell_size(n: int, cols: int) -> float:
	var rows := int(ceil(float(n) / float(cols)))
	var usable_w := 984.0
	var usable_h := 900.0
	var size := minf((usable_w - ThemeService.min_spacing() * (cols - 1)) / cols, (usable_h - ThemeService.min_spacing() * (rows - 1)) / rows)
	return clampf(size, ThemeService.min_touch_target(), 260.0)

func _play_sound() -> void:
	var audio: Dictionary = _current.get("audio", {})
	AudioService.speak(str(_current.get("item_id", "")) + "_sound", str(audio.get("sound", "")), "prompt")

func _on_replay_sound() -> void:
	SessionTimer.touch()
	Telemetry.emit_event("audio_replayed", {"item_id": str(_current.get("item_id", ""))})
	_play_sound()

func _on_cell_pressed(btn: Button) -> void:
	SessionTimer.touch()
	if _finish_requested or btn.disabled:
		return
	var tapped := str(btn.text)
	var target := str(_current.get("target", ""))
	var item_id := str(_current.get("item_id", ""))
	_attempts += 1
	if tapped == target:
		# cible touchée : s'illumine et reste visible
		_found_count += 1
		Sfx.pair_bell()
		btn.disabled = true
		btn.focus_mode = Control.FOCUS_NONE
		var sb := StyleBoxFlat.new()
		sb.bg_color = ThemeService.GOOD_SOFT
		sb.border_color = ThemeService.GOOD
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(int(Tuning.UI_CORNER_RADIUS_SMALL))
		btn.add_theme_stylebox_override("disabled", sb)
		btn.add_theme_color_override("font_disabled_color", ThemeService.GOOD)
		ThemeService.sparkle_burst(btn, btn.size * 0.5, ThemeService.GOOD)
		report_answer(item_id, true, {"target": target, "tapped": tapped, "was_target": true}, _attempts, Time.get_ticks_msec() - _item_start_ms)
		if _found_count >= int(_current.get("target_count", 0)):
			# grille terminée : mini-bilan puis suivante
			_set_status(Strings.RADAR_FOUND % [int(_current.get("target_count", 0)), target])
			complete_item(item_id, _attempts == int(_current.get("target_count", 0)), _attempts, 0)
			_dots.light_next()
			var timer := get_tree().create_timer(1.6)
			timer.timeout.connect(_next_grid)
	else:
		# mauvaise lettre : tremble doucement, la voix nomme la lettre ; elle reste en place
		ThemeService.gentle_shake(btn)
		_confusions.append({"tapped": tapped, "expected": target})
		report_answer(item_id, false, {"target": target, "tapped": tapped, "was_target": false}, _attempts, Time.get_ticks_msec() - _item_start_ms)
		_set_status(Strings.RADAR_WRONG % tapped)

func _finish_session_quietly() -> void:
	if _finished:
		return
	_finished = true
	# toutes les grilles travaillées : bref moment de célébration, jamais de score
	_set_status(Strings.SUCCESS_BRAVO)
	Sfx.celebration()
	var timer := get_tree().create_timer(Tuning.FX_CELEBRATION_MS / 1000.0)
	timer.timeout.connect(func() -> void:
		_set_status(Strings.SUMMARY_DONE % _items_done)
		finish_session("completed"))

func _process(_delta: float) -> void:
	# plafond de séance : 2 minutes d'activité au total (critère du document)
	if not _finish_requested and not _finished and _session_deadline_ms > 0 and Time.get_ticks_msec() >= _session_deadline_ms:
		_finish_session_quietly()

func _set_status(text: String) -> void:
	if _status != null:
		_status.text = text

func on_pause() -> void:
	SessionTimer.pause()

func on_resume() -> void:
	SessionTimer.resume()

func on_time_soft_end() -> void:
	pass

func on_time_limit() -> void:
	pass
