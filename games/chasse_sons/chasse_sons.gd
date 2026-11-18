extends MiniGame
## Chasse-Sons (game_id : chasse_sons) — discrimination auditive.
## L'enfant écoute un son cible (phonème ISOLÉ fourni, jamais le nom de la lettre) et touche
## les éléments dont le mot contient ce son. 3 à 6 éléments flottent lentement.
## Erreur : tremblement doux + retour court (ECAR) ; l'élément revient dans une manche ultérieure.
## Le jeu ne calcule PAS has_target : il lit la valeur fournie. Aucune chute rapide, aucun chrono.

const FloatingItem := preload("res://games/chasse_sons/floating_item.gd")

var _target: Dictionary = {}
var _round_items: Array = []          # items de la manche courante
var _pool: Array = []                 # items restants (hors manche courante)
var _round_no: int = 0
var _found_in_round: int = 0
var _targets_in_round: int = 0
var _main_vb: VBoxContainer = null
var _status: Label = null
var _items_layer: Control = null
var _speaker: Button = null
var _instruction: Label = null
var _item_start_ms: int = 0
var _dots: ProgressDots = null

func _setup(cfg: GameConfig) -> void:
	var errs := GameConfig.validate_chasse_config(cfg.raw)
	if not errs.is_empty():
		show_error_screen("config_invalid", "; ".join(errs))
		return
	_target = cfg.raw.get("target", {})
	# file : tous les items, ordre de la configuration ; les non-cibles en réserve pour manches
	_pool.assign(cfg.items)
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
	_main_vb.add_theme_constant_override("separation", 16)
	margin.add_child(_main_vb)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	_main_vb.add_child(top)
	_speaker = UIKit.speaker_button(_on_replay_instruction)
	top.add_child(_speaker)
	var title := Label.new()
	title.text = Strings.CHASSE_TITLE
	ThemeService.style_label(title, Tuning.FONT_SIZE_TITLE, ThemeService.INK, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(title)
	top.add_child(build_time_gauge())

	_instruction = Label.new()
	_instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeService.style_label(_instruction, Tuning.FONT_SIZE_BODY, ThemeService.INK, true)
	_main_vb.add_child(_instruction)

	# progression calme : une pastille par cible attendue dans la configuration
	var dots_wrap := CenterContainer.new()
	_dots = ProgressDots.new()
	var wanted_targets := 0
	for it in config.items:
		if bool(it.get("has_target", false)):
			wanted_targets += 1
	_dots.setup(maxi(wanted_targets, 1))
	dots_wrap.add_child(_dots)
	_main_vb.add_child(dots_wrap)

	_items_layer = Control.new()
	_items_layer.clip_contents = true
	_items_layer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main_vb.add_child(_items_layer)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeService.style_label(_status, int(Tuning.FONT_SIZE_BODY * 0.9), ThemeService.INK_SOFT)
	_main_vb.add_child(_status)

func on_start() -> void:
	_play_instruction()
	_new_round()

# --- manches ---

func _new_round() -> void:
	if _pool.is_empty():
		_finish_rounds()
		return
	_round_no += 1
	_found_in_round = 0
	_round_items.clear()
	for c in _items_layer.get_children():
		c.queue_free()
	# sélection : d'abord les cibles (au moins 2), puis des distracteurs, selon l'âge/niveau
	var targets: Array = []
	var others: Array = []
	for it in _pool:
		if bool(it.get("has_target", false)):
			targets.append(it)
		else:
			others.append(it)
	var max_elements: int = Tuning.CHASSE_ELEMENTS_MAX_CHILD if config.age_band == "6-8" else Tuning.CHASSE_ELEMENTS_MAX
	var want_targets: int = mini(Tuning.CHASSE_ROUND_TARGETS, targets.size())
	if config.age_band == "6-8":
		want_targets = mini(Tuning.CHASSE_ROUND_TARGETS_CHILD, targets.size())
	# prendre les cibles de la manche
	var round_targets: Array = targets.slice(0, want_targets)
	var remaining_slots: int = max_elements - round_targets.size()
	var round_others: Array = others.slice(0, maxi(remaining_slots, 0))
	_round_items = round_targets + round_others
	# retirer de la piscine
	for it in _round_items:
		_pool.erase(it)
	_targets_in_round = round_targets.size()
	if _targets_in_round < 2:
		# plus assez de cibles : fin propre des manches
		_finish_rounds()
		return
	_layout_items()
	_set_status("")

func _layout_items() -> void:
	# positions en grille stable + légère dérive sinusoïdale (jamais de chute)
	var n := _round_items.size()
	var cols: int = 2 if n <= 4 else 3
	var rows := int(ceil(float(n) / float(cols)))
	var area := _items_layer.get_rect().size
	if area.x < 10:
		area = Vector2(984, 1100)  # avant le premier layout : valeurs portrait par défaut
	var cell_w := area.x / cols
	var cell_h := area.y / maxi(rows, 1)
	var item_size := minf(minf(cell_w, cell_h) * 0.86, ThemeService.min_touch_target() * 1.9)
	item_size = maxf(item_size, ThemeService.min_touch_target())
	var i := 0
	for it in _round_items:
		var col := i % cols
		var row := i / cols
		var center := Vector2((col + 0.5) * cell_w, (row + 0.5) * cell_h)
		var item := FloatingItem.new_item(it, Vector2(item_size, item_size), ThemeService.skin_id)
		item.position = center - Vector2(item_size, item_size) * 0.5
		item.item_tapped.connect(_on_item_tapped)
		_items_layer.add_child(item)
		item.begin_drift(center, Tuning.CHASSE_DRIFT_AMPLITUDE, Tuning.CHASSE_DRIFT_PERIOD_S, i)
		ThemeService.gentle_appear(item, i * Tuning.FX_APPEAR_STAGGER_S)
		i += 1

# --- interactions ---

func _on_item_tapped(item: FloatingItem) -> void:
	SessionTimer.touch()
	if _finish_requested:
		return
	var data: Dictionary = item.data
	var item_id := str(data.get("item_id", ""))
	announce_item(item_id)
	_item_start_ms = Time.get_ticks_msec()
	# le mot est joué au toucher
	var audio: Dictionary = data.get("audio", {})
	AudioService.speak(item_id + "_word", str(audio.get("word", "")), "word")
	var has_target := bool(data.get("has_target", false))
	var position := str(data.get("position", ""))
	if has_target:
		# bonne réponse : l'élément éclot, réussite notée
		item.hatch()
		Sfx.pair_bell()
		_found_in_round += 1
		_dots.light_next()
		report_answer(item_id, true, {"phoneme_id": str(_target.get("phoneme_id", "")), "has_target": true, "tapped_target": true, "position": position}, 1, Time.get_ticks_msec() - _item_start_ms)
		complete_item(item_id, true, 1, 0)
		_set_status(Strings.CHASSE_SUCCESS % str(data.get("word", "")))
		_check_round_end()
	else:
		# erreur : tremblement doux, retour court, l'élément reviendra plus tard (réinsertion)
		item.gentle_shake()
		report_answer(item_id, false, {"phoneme_id": str(_target.get("phoneme_id", "")), "has_target": false, "tapped_target": false, "position": position}, 1, Time.get_ticks_msec() - _item_start_ms)
		var first_sound := str(data.get("word", "")).substr(0, 1)
		_set_status(_ecar_message(data, first_sound))
		# l'élément non-cible reste affiché mais on le renvoie dans une manche ultérieure s'il reste des manches
		if not _pool.has(data):
			_pool.append(data)

func _ecar_message(data: Dictionary, _first_sound: String) -> String:
	# ECAR court : encourager, corriger, expliquer, refaire — en nommant le mot et son premier son
	var word := str(data.get("word", ""))
	var pos := str(data.get("position", ""))
	var label := str(_target.get("label", ""))
	match pos:
		"start":
			return Strings.CHASSE_RETRY_START % [word, label]
		"middle":
			return Strings.CHASSE_RETRY_MIDDLE % [word, label]
		_:
			return Strings.CHASSE_RETRY_END % [word, label]

func _check_round_end() -> void:
	if _found_in_round >= _targets_in_round:
		_set_status(Strings.CHASSE_ROUND_DONE)
		emit_break("round_end")
		var timer := get_tree().create_timer(1.6)
		timer.timeout.connect(_new_round)

func _finish_rounds() -> void:
	_set_status(Strings.SUMMARY_DONE % _items_done)
	finish_session("completed")

# --- audio ---

func _play_instruction() -> void:
	# consigne vocale : le SON isolé fourni (target.audio_phoneme), jamais le nom de la lettre
	var url := str(_target.get("audio_phoneme", ""))
	if url.is_empty():
		Bridge.send_error("phoneme_audio_missing", "L'audio du son cible est absent : le jeu s'arrête proprement.")
		show_error_screen("phoneme_audio_missing", "Le son cible n'a pas son audio.")
		_finish_requested = true
		return
	AudioService.speak("instruction_phoneme", url, "prompt")
	_instruction.text = Strings.CHASSE_INSTRUCTION + " " + str(_target.get("label", ""))

func _on_replay_instruction() -> void:
	SessionTimer.touch()
	Telemetry.emit_event("audio_replayed", {"item_id": "instruction"})
	_play_instruction()

func _set_status(text: String) -> void:
	if _status != null:
		_status.text = text

func on_pause() -> void:
	SessionTimer.pause()

func on_resume() -> void:
	SessionTimer.resume()

func on_time_soft_end() -> void:
	pass  # l'élément en cours se termine, puis scène de repos (gérée par main)

func on_time_limit() -> void:
	pass
