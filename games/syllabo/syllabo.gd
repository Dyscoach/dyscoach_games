extends MiniGame
## Syllabo (game_id : syllabo) — découpage syllabique.
## L'enfant frappe un tambour une fois par syllabe et un train se construit.
## Le jeu ne calcule JAMAIS le découpage : il lit syllables et syllable_count fournis.
## Validation au bouton « c'est fini » ou automatique après 3 s sans toucher (Tuning).

var _queue: Array = []
var _current: Dictionary = {}
var _tapped_count: int = 0
var _attempt_no: int = 0
var _auto_validated: bool = false
var _last_tap_ms: int = 0
var _item_start_ms: int = 0
var _main_vb: VBoxContainer = null
var _status: Label = null
var _word_label: Label = null
var _drum: Button = null
var _train_box: HBoxContainer = null
var _finish_btn: Button = null
var _speaker: Button = null
var _dots: ProgressDots = null
var _initial_count: int = 0
var _finished: bool = false

func _setup(cfg: GameConfig) -> void:
	var errs := GameConfig.validate_syllabo_items(cfg.items)
	if not errs.is_empty():
		show_error_screen("config_invalid", "; ".join(errs))
		return
	for item in cfg.items:
		_queue.append(item.duplicate())
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
	_main_vb.add_theme_constant_override("separation", 20)
	margin.add_child(_main_vb)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	_main_vb.add_child(top)
	_speaker = UIKit.speaker_button(_on_replay)
	top.add_child(_speaker)
	var title := Label.new()
	title.text = Strings.SYL_TITLE
	ThemeService.style_label(title, Tuning.FONT_SIZE_TITLE, ThemeService.INK, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(title)
	top.add_child(build_time_gauge())

	# consigne écrite affichée en permanence sous le titre (une seule idée, courte)
	var instruction := Label.new()
	instruction.text = Strings.SYL_TAP_HINT
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeService.style_label(instruction, int(Tuning.FONT_SIZE_BODY * 0.8), ThemeService.INK_SOFT)
	_main_vb.add_child(instruction)

	# progression calme : une pastille par mot de la configuration (réinsertions gardées)
	var dots_wrap := CenterContainer.new()
	_dots = ProgressDots.new()
	_initial_count = maxi(config.items.size(), 1)
	_dots.setup(_initial_count)
	dots_wrap.add_child(_dots)
	_main_vb.add_child(dots_wrap)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeService.style_label(_status, Tuning.FONT_SIZE_BODY, ThemeService.INK)
	_main_vb.add_child(_status)

	_word_label = Label.new()
	_word_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeService.style_label(_word_label, int(Tuning.FONT_SIZE_TITLE * 0.8), ThemeService.INK, true)
	_main_vb.add_child(_word_label)

	# le train : un wagon apparaît par frappe de tambour
	var train_center := CenterContainer.new()
	train_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main_vb.add_child(train_center)
	_train_box = HBoxContainer.new()
	_train_box.add_theme_constant_override("separation", ThemeService.min_spacing())
	train_center.add_child(_train_box)

	# tambour au centre-bas : grande cible tactile
	var drum_center := CenterContainer.new()
	_main_vb.add_child(drum_center)
	_drum = Button.new()
	_drum.text = "🥁" if ThemeService.age_band == "6-8" or ThemeService.age_band == "9-11" else "Tambour"
	_drum.add_theme_font_override("font", ThemeService.font_bold())
	_drum.add_theme_font_size_override("font_size", 96)
	var d := maxf(ThemeService.min_touch_target() * 1.6, 240.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = ThemeService.ACCENT
	sb.set_corner_radius_all(int(d / 2.0))
	_drum.add_theme_stylebox_override("normal", sb)
	var sb2 := sb.duplicate()
	sb2.bg_color = ThemeService.ACCENT.darkened(0.15)
	_drum.add_theme_stylebox_override("pressed", sb2)
	_drum.custom_minimum_size = Vector2(d, d)
	_drum.pressed.connect(_on_drum)
	drum_center.add_child(_drum)

	_finish_btn = UIKit.big_button(Strings.FINISH, _on_finish_pressed)
	_main_vb.add_child(_finish_btn)

func on_start() -> void:
	_next_word()

func _next_word() -> void:
	if _queue.is_empty() or _finish_requested:
		if not _finished:
			# tous les mots travaillés : bref moment de célébration, jamais de score
			_finished = true
			_set_status(Strings.SUCCESS_BRAVO)
			Sfx.celebration()
			var timer := get_tree().create_timer(Tuning.FX_CELEBRATION_MS / 1000.0)
			timer.timeout.connect(func() -> void:
				_set_status(Strings.SUMMARY_DONE % _items_done)
				finish_session("completed"))
		return
	_current = _queue.pop_front()
	_tapped_count = 0
	_attempt_no = 0
	_auto_validated = false
	_item_start_ms = Time.get_ticks_msec()
	_last_tap_ms = Time.get_ticks_msec()
	announce_item(str(_current.get("item_id", "")))
	_word_label.text = str(_current.get("word", ""))
	for c in _train_box.get_children():
		c.queue_free()
	_set_status(Strings.SYL_TAP_HINT)
	_play_word()

func _play_word() -> void:
	var audio: Dictionary = _current.get("audio", {})
	AudioService.speak(str(_current.get("item_id", "")) + "_word", str(audio.get("word", "")), "word")

func _on_replay() -> void:
	SessionTimer.touch()
	Telemetry.emit_event("audio_replayed", {"item_id": str(_current.get("item_id", ""))})
	_play_word()

# --- tambour ---

func _on_drum() -> void:
	if _finish_requested or _train_box == null:
		return
	SessionTimer.touch()
	_last_tap_ms = Time.get_ticks_msec()
	ThemeService.success_pulse(_drum)
	# un toucher = un wagon : le nombre de wagons suit exactement le nombre de touchers
	_tapped_count += 1
	_add_wagon()
	Sfx.soft_flip()
	if AudioService.mode == AudioService.Mode.LOCAL:
		AudioService.play_gentle_pop()

func _add_wagon() -> void:
	var wagon := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = ThemeService.SURFACE
	sb.border_color = ThemeService.ACCENT
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(int(Tuning.UI_CORNER_RADIUS_SMALL))
	wagon.add_theme_stylebox_override("panel", sb)
	wagon.custom_minimum_size = Vector2(150, 130)
	# corps du wagon : un caisson avec deux roues dessinées (une frappe = un wagon complet)
	var body := VBoxContainer.new()
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	var caisson := ColorRect.new()
	caisson.color = ThemeService.ACCENT_SOFT
	caisson.custom_minimum_size = Vector2(110, 44)
	var wheels := HBoxContainer.new()
	wheels.alignment = BoxContainer.ALIGNMENT_CENTER
	wheels.add_theme_constant_override("separation", 26)
	for i in 2:
		var wheel := ColorRect.new()
		wheel.color = ThemeService.INK
		wheel.custom_minimum_size = Vector2(22, 22)
		wheels.add_child(wheel)
	body.add_child(caisson)
	body.add_child(wheels)
	wagon.add_child(body)
	_train_box.add_child(wagon)
	ThemeService.gentle_appear(wagon)

# --- validation ---

func _on_finish_pressed() -> void:
	SessionTimer.touch()
	_validate(false)

func _validate(auto: bool) -> void:
	if _finish_requested or _current.is_empty():
		return
	var expected := int(_current.get("syllable_count", 0))
	_attempt_no += 1
	var detail := {"expected_count": expected, "tapped_count": _tapped_count, "auto_validated": auto}
	if _tapped_count == expected:
		# bonne réponse : le train « roule », la voix redit le mot découpé en éclairant les wagons
		report_answer(str(_current.get("item_id", "")), true, detail, _attempt_no, Time.get_ticks_msec() - _item_start_ms)
		_complete_word()
	else:
		report_answer(str(_current.get("item_id", "")), false, detail, _attempt_no, Time.get_ticks_msec() - _item_start_ms)
		# autre nombre : redécoupage lent, puis l'enfant réessaie une fois
		_set_status(Strings.SYL_RETRY)
		_slow_decompose()
		if _attempt_no >= 2:
			# après un 2e essai raté : le mot revient plus tard (réinsertion), on passe au suivant
			_queue.append(_current.duplicate())
			var timer := get_tree().create_timer(2.4)
			timer.timeout.connect(_next_word)
		else:
			# nouvel essai : on vide le train
			var t2 := get_tree().create_timer(2.4)
			t2.timeout.connect(func() -> void:
				_tapped_count = 0
				for c in _train_box.get_children():
					c.queue_free())

func _slow_decompose() -> void:
	# la voix redécoupe lentement (audio slow s'il existe, sinon éclaire les wagons)
	var audio: Dictionary = _current.get("audio", {})
	var slow := str(audio.get("slow", ""))
	if slow != "":
		AudioService.speak(str(_current.get("item_id", "")) + "_slow", slow, "prompt")

func _complete_word() -> void:
	var word := str(_current.get("word", ""))
	_set_status(Strings.SYL_SUCCESS % [int(_current.get("syllable_count", 0)), word])
	# la voix redit le mot en le découpant (syllabes fournies), un wagon éclairé par syllabe
	var syllables: Array = _current.get("syllables", [])
	_glow_wagons(0, syllables)
	complete_item(str(_current.get("item_id", "")), _attempt_no == 1, _attempt_no, 0)
	ThemeService.sparkle_burst(_train_box, _train_box.size * 0.5)
	if AudioService.mode == AudioService.Mode.LOCAL:
		AudioService.play_success_chime()
	_dots.light_next()
	var timer := get_tree().create_timer(2.0)
	timer.timeout.connect(_next_word)

func _glow_wagons(index: int, syllables: Array) -> void:
	if index >= _train_box.get_child_count() or index >= syllables.size():
		return
	var wagon: PanelContainer = _train_box.get_child(index)
	ThemeService.success_pulse(wagon)
	# audio de la syllabe si fourni
	var syl: Dictionary = syllables[index] if typeof(syllables[index]) == TYPE_DICTIONARY else {}
	var url := str(syl.get("audio", ""))
	if url != "":
		AudioService.speak("%s_syl_%d" % [str(_current.get("item_id", "")), index], url, "prompt")
	var timer := get_tree().create_timer(0.6)
	timer.timeout.connect(func() -> void: _glow_wagons(index + 1, syllables))

func _process(_delta: float) -> void:
	# validation automatique après 3 s sans toucher (désactivable via Tuning)
	if Tuning.SYLLABO_AUTOVALIDATE_ENABLED and not _finish_requested and not _current.is_empty() and _tapped_count > 0 and not _auto_validated and _attempt_no == 0:
		if Time.get_ticks_msec() - _last_tap_ms >= Tuning.SYLLABO_AUTOVALIDATE_MS:
			_auto_validated = true
			_validate(true)

func _set_status(text: String) -> void:
	if _status != null:
		_status.text = text

func on_pause() -> void:
	SessionTimer.pause()

func on_resume() -> void:
	SessionTimer.resume()
	_last_tap_ms = Time.get_ticks_msec()

func on_time_soft_end() -> void:
	pass

func on_time_limit() -> void:
	pass
