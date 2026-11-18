extends MiniGame
## Forge-Mots (game_id : forge_mots) — dictée à tuiles.
## Une voix dit un mot, l'enfant le reconstitue avec des tuiles de graphèmes.
## Aucune saisie clavier, jamais. Deux modes d'entrée : glisser OU toucher-puis-toucher.
## Validation : per_item (à chaque tuile posée) ou at_end (quand toutes les cases sont remplies).
## Aides (Tuning) : inaction 10 s OU 2 erreurs → tuile qui brille ; 3 erreurs → décomposition
## sonore, mot marqué "à revoir" et réinséré au plus 1 fois.

const GraphemeTile := preload("res://games/forge_mots/grapheme_tile.gd")

var _queue: Array = []                 # items restants à présenter (avec réinsertions)
var _current: Dictionary = {}
var _slots: Array[String] = []         # graphèmes attendus, dans l'ordre
var _filled: Array[String] = []        # graphèmes posés ("" si case vide)
var _reserve_tiles: Array[GraphemeTile] = []
var _slot_tiles: Array[Button] = []
var _attempt_no: int = 0
var _slot_errors: Dictionary = {}      # index de case -> nb d'erreurs
var _hints_used: int = 0
var _last_action_ms: int = 0
var _glow_shown_for: Dictionary = {}   # index -> true (hint tile_glow déjà montré sur la case)
var _spell_out_done: bool = false
var _first_try: bool = true
var _validation_at_end: bool = false
var _tap_selected: GraphemeTile = null
var _finished_words: int = 0
var _item_start_ms: int = 0
var _main_vb: VBoxContainer = null
var _slots_box: HBoxContainer = null
var _reserve_grid: GridContainer = null
var _status: Label = null
var _speaker: Button = null
var _validate_btn: Button = null

func _setup(cfg: GameConfig) -> void:
	_validation_at_end = cfg.interaction_validation == "at_end"
	var errs := GameConfig.validate_forge_items(cfg.items)
	if not errs.is_empty():
		show_error_screen("config_invalid", "; ".join(errs))
		return
	# file initiale : tous les items, dans l'ordre
	for item in cfg.items:
		_queue.append({"item": item, "reinsertions": 0})
	_build_ui()

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
	_speaker = UIKit.speaker_button(_on_replay_word)
	top.add_child(_speaker)
	var title := Label.new()
	title.text = Strings.FORGE_TITLE
	ThemeService.style_label(title, Tuning.FONT_SIZE_TITLE, ThemeService.INK, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(title)
	top.add_child(build_time_gauge())

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeService.style_label(_status, Tuning.FONT_SIZE_BODY, ThemeService.INK)
	_main_vb.add_child(_status)

	# zone centrale : image (carte neutre si absente) + cases — hauteur adaptative :
	# la carte image ne doit jamais pousser cases ni réserve hors du viewport.
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.clip_contents = true
	_main_vb.add_child(center)
	var mid := VBoxContainer.new()
	mid.add_theme_constant_override("separation", 16)
	center.add_child(mid)
	var image_card := UIKit.card_panel()
	# la carte image occupe au plus 18 % de la hauteur utile de la zone centrale
	image_card.custom_minimum_size = Vector2(240, 220)
	var image_wrap := CenterContainer.new()
	image_wrap.add_child(image_card)
	mid.add_child(image_wrap)
	_slots_box = HBoxContainer.new()
	_slots_box.add_theme_constant_override("separation", ThemeService.min_spacing())
	_slots_box.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_child(_slots_box)

	# réserve de tuiles en bas : ancrée en bas de l'écran, jamais coupée
	_reserve_grid = GridContainer.new()
	_reserve_grid.add_theme_constant_override("h_separation", ThemeService.min_spacing())
	_reserve_grid.add_theme_constant_override("v_separation", ThemeService.min_spacing())
	_reserve_grid.columns = UIKit.columns_for_width(1080 - 96 - 64, ThemeService.min_touch_target() + Tuning.TOUCH_SPACING_MIN)
	var reserve_wrap := CenterContainer.new()
	reserve_wrap.size_flags_vertical = Control.SIZE_SHRINK_END
	reserve_wrap.custom_minimum_size = Vector2(0, _reserve_height())
	reserve_wrap.clip_contents = true
	reserve_wrap.add_child(_reserve_grid)
	_main_vb.add_child(reserve_wrap)

	if _validation_at_end:
		_validate_btn = UIKit.big_button(Strings.OK, _on_validate_pressed)
		_validate_btn.disabled = true
		_main_vb.add_child(_validate_btn)

func on_start() -> void:
	_next_word()

# --- file d'items ---

func _next_word() -> void:
	if _queue.is_empty() or _finish_requested:
		_show_summary()
		return
	var entry: Dictionary = _queue.pop_front()
	_current = entry["item"]
	_attempt_no = 0
	_slot_errors.clear()
	_hints_used = 0
	_glow_shown_for.clear()
	_spell_out_done = false
	_first_try = true
	_last_action_ms = Time.get_ticks_msec()
	_item_start_ms = Time.get_ticks_msec()
	announce_item(str(_current.get("item_id", "")))
	_build_word()
	_play_word_audio()

func _build_word() -> void:
	# cas par type d'item
	var itype := str(_current.get("item_type", "word"))
	match itype:
		"homophone":
			_build_homophone()
		"sentence":
			_build_sentence()
		_:
			_build_word_tiles()

func _build_word_tiles() -> void:
	_slots.assign([])
	for g in _current.get("graphemes", []):
		_slots.append(str(g))
	_filled.assign([])
	for i in _slots.size():
		_filled.append("")
	_clear_slots_box()
	_clear_reserve()
	_slot_tiles.clear()
	_reserve_tiles.clear()
	# cases vides
	for i in _slots.size():
		var slot := Button.new()
		slot.custom_minimum_size = Vector2(_tile_size(), _tile_size())
		slot.disabled = true
		slot.focus_mode = Control.FOCUS_NONE
		var sb := StyleBoxFlat.new()
		sb.bg_color = ThemeService.SURFACE
		sb.border_color = ThemeService.BORDER
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(int(Tuning.UI_CORNER_RADIUS_SMALL))
		slot.add_theme_stylebox_override("disabled", sb)
		slot.text = ""
		slot.add_theme_font_override("font", ThemeService.font_bold())
		slot.add_theme_font_size_override("font_size", int(Tuning.FONT_SIZE_TILE * 0.8))
		slot.add_theme_color_override("font_disabled_color", ThemeService.BORDER)
		# les cases acceptent le drop et le tap (sélection)
		slot.gui_input.connect(_on_slot_gui_input.bind(i))
		var target := GraphemeTile.DropTarget.new()
		target.slot_index = i
		slot.set_meta("drop_target", target)
		_slots_box.add_child(slot)
		_slot_tiles.append(slot)
	# réserve : graphèmes du mot + leurres, ordre stable mélangé côté affichage seulement
	var tiles: Array[String] = []
	for g in _slots:
		tiles.append(g)
	for d in _current.get("distractors", []):
		tiles.append(str(d))
	var display: Array = tiles.duplicate()
	display.shuffle()
	for g in display:
		_add_reserve_tile(g)
	_update_validate_state()
	_set_status("")

func _tile_size() -> float:
	var n := maxi(_slots.size(), 1)
	var usable := 1080.0 - 96.0  # marges
	var spacing := ThemeService.min_spacing() * (n - 1)
	var s := minf((usable - spacing) / n, ThemeService.min_touch_target() * 1.35)
	return maxf(s, ThemeService.min_touch_target())

## Hauteur disponible pour la réserve : 1 à 2 rangées de tuiles selon leur taille,
## calculée pour rester entièrement visible dans le viewport (1080x1920 portrait).
func _reserve_height() -> float:
	var tile := _tile_size()
	var n_tiles := maxi(_slots.size() + _current_learers_count(), 1)
	var columns := maxi(_reserve_grid.columns, 1)
	var rows := int(ceil(float(n_tiles) / float(columns)))
	return clampf(rows * tile + (rows - 1) * ThemeService.min_spacing(), tile, 2.0 * tile + ThemeService.min_spacing())

func _current_learers_count() -> int:
	if _current.is_empty():
		return 0
	var d: Array = _current.get("distractors", [])
	return d.size()

func _add_reserve_tile(grapheme: String) -> void:
	var tile := GraphemeTile.new_tile(grapheme, Vector2(_tile_size(), _tile_size()))
	tile.tapped.connect(_on_tile_tapped.bind(tile))
	_reserve_grid.add_child(tile)
	_reserve_tiles.append(tile)

func _clear_reserve() -> void:
	for t in _reserve_tiles:
		t.queue_free()
	_reserve_tiles.clear()

func _clear_slots_box() -> void:
	for c in _slots_box.get_children():
		c.queue_free()
	_slot_tiles.clear()

# --- audio ---

func _play_word_audio() -> void:
	var audio: Dictionary = _current.get("audio", {})
	var url := str(audio.get("word", ""))
	AudioService.speak(str(_current.get("item_id", "")) + "_word", url, "word")

func _on_replay_word() -> void:
	SessionTimer.touch()
	Telemetry.emit_event("audio_replayed", {"item_id": str(_current.get("item_id", ""))})
	_play_word_audio()

# --- interactions tuiles ---

func _on_tile_tapped(tile: GraphemeTile) -> void:
	SessionTimer.touch()
	_last_action_ms = Time.get_ticks_msec()
	if tile.locked:
		return
	# mode toucher-puis-toucher : sélection
	if _tap_selected != null and _tap_selected != tile:
		_tap_selected.set_selected(false)
	_tap_selected = tile
	tile.set_selected(true)
	_set_status("")
	# en mode glisser, le tap sélectionne aussi ; le drop confirme

func _on_slot_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		SessionTimer.touch()
		_last_action_ms = Time.get_ticks_msec()
		if _tap_selected != null and not _slot_tiles[index].disabled:
			_place_tile(_tap_selected, index)
	# glisser-déposer : la tuile sélectionnée est posée sur la case au clic
	# (mode drag natif hors écran tactile : le clic-tap couvre les deux interactions)

func _place_tile(tile: GraphemeTile, index: int) -> void:
	if _filled[index] != "":
		# case occupée : on renvoie l'ancienne tuile en réserve
		var old := _filled[index]
		_return_to_reserve(old, index)
	_place_tile_into(tile, index)

func _place_tile_into(tile: GraphemeTile, index: int) -> void:
	_filled[index] = tile.grapheme
	_slot_tiles[index].text = tile.grapheme
	_slot_tiles[index].disabled = false
	_slot_tiles[index].focus_mode = Control.FOCUS_NONE
	_reserve_tiles.erase(tile)
	tile.queue_free()
	_tap_selected = null
	if not _validation_at_end:
		_check_slot(index)
	_update_validate_state()

func _return_to_reserve(grapheme: String, index: int) -> void:
	_filled[index] = ""
	_slot_tiles[index].text = ""
	var sb := StyleBoxFlat.new()
	sb.bg_color = ThemeService.SURFACE
	sb.border_color = ThemeService.BORDER
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(int(Tuning.UI_CORNER_RADIUS_SMALL))
	_slot_tiles[index].add_theme_stylebox_override("disabled", sb)
	_add_reserve_tile(grapheme)

func _check_slot(index: int) -> void:
	var placed := _filled[index]
	var expected := _slots[index]
	var tile_pair := _confusion_pair(placed, expected)
	if placed == expected:
		# bonne tuile : verrouillage + éclat discret
		var sb := StyleBoxFlat.new()
		sb.bg_color = ThemeService.GOOD_SOFT
		sb.border_color = ThemeService.GOOD
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(int(Tuning.UI_CORNER_RADIUS_SMALL))
		_slot_tiles[index].add_theme_stylebox_override("disabled", sb)
		_slot_tiles[index].add_theme_color_override("font_disabled_color", ThemeService.GOOD)
		ThemeService.sparkle_burst(_slot_tiles[index], _slot_tiles[index].size * 0.5, ThemeService.GOOD)
		report_answer(str(_current.get("item_id", "")), true, {"expected": expected, "chosen": placed, "tile_pair": tile_pair, "mode": "tile"}, _attempt_no, Time.get_ticks_msec() - _item_start_ms)
		if _all_filled():
			_word_complete()
	else:
		_attempt_no += 1
		_first_try = false
		var errs: int = int(_slot_errors.get(index, 0)) + 1
		_slot_errors[index] = errs
		# la tuile revient doucement à la réserve, sans son négatif
		ThemeService.gentle_shake(_slot_tiles[index])
		var tile := _find_reserve_like(placed)
		if tile != null:
			_place_back(tile, index)
		else:
			_return_to_reserve(placed, index)
		report_answer(str(_current.get("item_id", "")), false, {"expected": expected, "chosen": placed, "tile_pair": tile_pair, "mode": "tile"}, _attempt_no, Time.get_ticks_msec() - _item_start_ms)
		_set_status(Strings.FORGE_RETRY)
		_maybe_show_hint(index, errs)

func _place_back(tile: GraphemeTile, index: int) -> void:
	_filled[index] = ""
	_slot_tiles[index].text = ""
	var sb := StyleBoxFlat.new()
	sb.bg_color = ThemeService.SURFACE
	sb.border_color = ThemeService.BORDER
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(int(Tuning.UI_CORNER_RADIUS_SMALL))
	_slot_tiles[index].add_theme_stylebox_override("disabled", sb)
	_reserve_grid.add_child(tile)
	_reserve_tiles.append(tile)

func _find_reserve_like(grapheme: String) -> GraphemeTile:
	# une tuile identique en réserve peut être réutilisée ; sinon on recrée
	for t in _reserve_tiles:
		if t.grapheme == grapheme and not t.locked:
			return t
	return null

func _confusion_pair(a: String, b: String) -> String:
	for pair in Tuning.CONFUSION_PAIRS:
		if (a == pair[0] and b == pair[1]) or (a == pair[1] and b == pair[0]):
			return "%s/%s" % [pair[0], pair[1]]
	return ""

# --- aides ---

func _maybe_show_hint(index: int, errs: int) -> void:
	if not config.hints_enabled:
		return
	if _spell_out_done:
		return
	var idle_too_long := Time.get_ticks_msec() - _last_action_ms >= Tuning.FORGE_GLOW_AFTER_IDLE_MS
	if (idle_too_long or errs >= Tuning.FORGE_GLOW_AFTER_ERRORS) and not _glow_shown_for.has(index):
		_glow_shown_for[index] = true
		_hints_used += 1
		Telemetry.emit_event("hint_shown", {"item_id": str(_current.get("item_id", "")), "hint_type": "tile_glow"})
		_glow_correct_tile(index)
		_set_status(Strings.FORGE_HINT_GLOW)
	if errs >= Tuning.FORGE_SPELL_OUT_AFTER_ERRORS:
		_spell_out_done = true
		_hints_used += 1
		Telemetry.emit_event("hint_shown", {"item_id": str(_current.get("item_id", "")), "hint_type": "spell_out"})
		_spell_out_word()

func _glow_correct_tile(index: int) -> void:
	var expected := _slots[index]
	for t in _reserve_tiles:
		if t.grapheme == expected and not t.locked:
			t.start_glow()
			return

func _spell_out_word() -> void:
	_set_status(Strings.FORGE_SPELL_OUT)
	# la voix décompose le mot son par son en éclairant chaque case
	var syllables: Array = _current.get("syllables", [])
	var audio: Dictionary = _current.get("audio", {})
	var slow_url := str(audio.get("slow", ""))
	if slow_url != "":
		AudioService.speak(str(_current.get("item_id", "")) + "_slow", slow_url, "prompt")
	elif not syllables.is_empty():
		# pas d'audio slow : on éclaire les cases séquentiellement, retour visuel seul
		_sequential_glow(0)
	# le mot est marqué "à revoir" et réinséré (max 1 réinsertion)
	var entry_reinsertions: int = int(_current.get("_reinsertions", 0))
	if entry_reinsertions < Tuning.FORGE_MAX_REINSERTIONS:
		var item: Dictionary = _current.duplicate()
		item["_reinsertions"] = entry_reinsertions + 1
		_queue.append({"item": item, "reinsertions": entry_reinsertions + 1})
		_set_status(Strings.FORGE_WORD_TO_REVIEW)

func _sequential_glow(index: int) -> void:
	if index >= _slot_tiles.size():
		return
	ThemeService.success_pulse(_slot_tiles[index])
	var timer := get_tree().create_timer(0.5)
	timer.timeout.connect(func() -> void: _sequential_glow(index + 1))

# --- validation at_end ---

func _all_filled() -> bool:
	for f in _filled:
		if f == "":
			return false
	return true

func _update_validate_state() -> void:
	if _validate_btn != null:
		_validate_btn.disabled = not _all_filled()

func _on_validate_pressed() -> void:
	SessionTimer.touch()
	var all_correct := true
	for i in _slots.size():
		if _filled[i] != _slots[i]:
			all_correct = false
			_attempt_no += 1
			_first_try = false
			var errs: int = int(_slot_errors.get(i, 0)) + 1
			_slot_errors[i] = errs
			report_answer(str(_current.get("item_id", "")), false, {"expected": _slots[i], "chosen": _filled[i], "tile_pair": _confusion_pair(_filled[i], _slots[i]), "mode": "word"}, _attempt_no, Time.get_ticks_msec() - _item_start_ms)
			ThemeService.gentle_shake(_slot_tiles[i])
	if all_correct:
		_word_complete()
	else:
		_set_status(Strings.FORGE_RETRY)
		_maybe_show_hint(_first_error_index(), 1)

func _first_error_index() -> int:
	for i in _slots.size():
		if _filled[i] != _slots[i]:
			return i
	return 0

# --- fin de mot ---

func _word_complete() -> void:
	var word := str(_current.get("word", _current.get("item_id", "")))
	_set_status(Strings.FORGE_SUCCESS_WORD % word)
	# la voix redit le mot en syllabes
	var audio: Dictionary = _current.get("audio", {})
	if str(audio.get("word", "")) != "":
		AudioService.speak(str(_current.get("item_id", "")) + "_again", str(audio.get("word", "")), "feedback")
	ThemeService.sparkle_burst(_slots_box, _slots_box.size * 0.5)
	for t in _slot_tiles:
		ThemeService.success_pulse(t)
	if AudioService.mode == AudioService.Mode.LOCAL:
		AudioService.play_success_chime()
	complete_item(str(_current.get("item_id", "")), _first_try, _attempt_no + 1, _hints_used)
	var timer := get_tree().create_timer(1.6)
	timer.timeout.connect(_next_word)

# --- homophones (niveau 4) ---

func _build_homophone() -> void:
	_clear_slots_box()
	_clear_reserve()
	# phrase à trou + choix en grandes cartes
	var sentence := str(_current.get("sentence_before", "")) + " ___ " + str(_current.get("sentence_after", ""))
	_slots_box.add_child(_make_sentence_label(sentence))
	for choice in _current.get("choices", []):
		var card := UIKit.tile(str(choice), Vector2(240, 200))
		card.pressed.connect(_on_homophone_choice.bind(str(choice), card))
		_slots_box.add_child(card)
	_set_status("")

func _on_homophone_choice(choice: String, card: Button) -> void:
	SessionTimer.touch()
	var answer := str(_current.get("answer", ""))
	var correct := choice == answer
	_attempt_no += 1
	if correct:
		var sb := StyleBoxFlat.new()
		sb.bg_color = ThemeService.GOOD_SOFT
		sb.border_color = ThemeService.GOOD
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(int(Tuning.UI_CORNER_RADIUS_SMALL))
		card.add_theme_stylebox_override("disabled", sb)
		card.disabled = true
		report_answer(str(_current.get("item_id", "")), true, {"expected": answer, "chosen": choice, "tile_pair": "", "mode": "homophone"}, _attempt_no, Time.get_ticks_msec() - _item_start_ms)
		complete_item(str(_current.get("item_id", "")), _attempt_no == 1, _attempt_no, 0)
		var timer := get_tree().create_timer(1.4)
		timer.timeout.connect(_next_word)
	else:
		_first_try = false
		ThemeService.gentle_shake(card)
		report_answer(str(_current.get("item_id", "")), false, {"expected": answer, "chosen": choice, "tile_pair": _confusion_pair(choice, answer), "mode": "homophone"}, _attempt_no, Time.get_ticks_msec() - _item_start_ms)
		_set_status(Strings.FORGE_RETRY)

func _make_sentence_label(sentence: String) -> Label:
	var lbl := Label.new()
	lbl.text = sentence
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeService.style_label(lbl, Tuning.FONT_SIZE_BODY, ThemeService.INK, true)
	return lbl

# --- phrases (niveau 5) ---

func _build_sentence() -> void:
	_slots.assign([])
	for w in _current.get("words", []):
		_slots.append(str(w))
	_filled.assign([])
	for i in _slots.size():
		_filled.append("")
	_clear_slots_box()
	_clear_reserve()
	_slot_tiles.clear()
	_reserve_tiles.clear()
	for i in _slots.size():
		var slot := Button.new()
		slot.custom_minimum_size = Vector2(200, 130)
		slot.disabled = true
		slot.focus_mode = Control.FOCUS_NONE
		slot.add_theme_font_override("font", ThemeService.font_bold())
		slot.add_theme_font_size_override("font_size", Tuning.FONT_SIZE_TILE_SMALL)
		var sb := StyleBoxFlat.new()
		sb.bg_color = ThemeService.SURFACE
		sb.border_color = ThemeService.BORDER
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(int(Tuning.UI_CORNER_RADIUS_SMALL))
		slot.add_theme_stylebox_override("disabled", sb)
		slot.gui_input.connect(_on_slot_gui_input.bind(i))
		_slots_box.add_child(slot)
		_slot_tiles.append(slot)
	var tiles: Array[String] = []
	for w in _slots:
		tiles.append(w)
	for d in _current.get("distractors", []):
		tiles.append(str(d))
	var display: Array = tiles.duplicate()
	display.shuffle()
	for w in display:
		var tile := GraphemeTile.new_tile(w, Vector2(200, 130))
		tile.tapped.connect(_on_tile_tapped.bind(tile))
		_reserve_grid.add_child(tile)
		_reserve_tiles.append(tile)

# --- divers ---

func _set_status(text: String) -> void:
	if _status != null:
		_status.text = text

func _show_summary() -> void:
	_set_status(Strings.SUMMARY_DONE % _finished_words)
	finish_session("completed")

func _process(_delta: float) -> void:
	# aide par inaction (10 s sans rien toucher) : la bonne tuile de la première case vide brille
	if config != null and config.hints_enabled and not _current.is_empty() and not _spell_out_done:
		if Time.get_ticks_msec() - _last_action_ms >= Tuning.FORGE_GLOW_AFTER_IDLE_MS:
			var idx := _first_empty_slot()
			if idx >= 0 and not _glow_shown_for.has(idx):
				_glow_shown_for[idx] = true
				_hints_used += 1
				Telemetry.emit_event("hint_shown", {"item_id": str(_current.get("item_id", "")), "hint_type": "tile_glow"})
				_glow_correct_tile(idx)
				_set_status(Strings.FORGE_HINT_GLOW)

func _first_empty_slot() -> int:
	for i in _filled.size():
		if _filled[i] == "":
			return i
	return -1

func on_pause() -> void:
	SessionTimer.pause()

func on_resume() -> void:
	SessionTimer.resume()
	_last_action_ms = Time.get_ticks_msec()

func on_time_soft_end() -> void:
	# on termine l'élément en cours puis repos (MiniGame gère la scène de repos via main)
	pass

func on_time_limit() -> void:
	pass
