extends MiniGame
## Duo-Mots (game_id : duo_mots) — paires minimales.
## L'enfant entend un mot cible et touche la bonne image parmi 2 (ou 3 aux niveaux 3+).
## Les cartes ont TOUJOURS exactement la même taille et le même style.
## Erreur : tremblement doux + les deux mots sont redits lentement ; la paire revient plus tard
## avec l'autre mot comme cible. Variante écrite au niveau 4 (10 ans et plus).

var _queue: Array = []                 # paires restantes (avec variantes cible A/B)
var _current: Dictionary = {}
var _cards: Array = []                 # boutons cartes affichés
var _first_try: bool = true
var _attempts: int = 0
var _item_start_ms: int = 0
var _main_vb: VBoxContainer = null
var _cards_row: HBoxContainer = null
var _status: Label = null
var _speaker: Button = null

func _setup(cfg: GameConfig) -> void:
	var errs := GameConfig.validate_duo_items(cfg.items)
	if not errs.is_empty():
		show_error_screen("config_invalid", "; ".join(errs))
		return
	# file : chaque paire jouée avec sa cible de la configuration (target_index),
	# puis rejouée avec l'AUTRE mot comme cible après une erreur
	for item in cfg.items:
		_queue.append({"item": item.duplicate(), "target": int(item.get("target_index", 0))})
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
	title.text = Strings.DUO_TITLE
	ThemeService.style_label(title, Tuning.FONT_SIZE_TITLE, ThemeService.INK, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(title)
	top.add_child(build_time_gauge())

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeService.style_label(_status, Tuning.FONT_SIZE_BODY, ThemeService.INK)
	_main_vb.add_child(_status)

	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main_vb.add_child(center)
	_cards_row = HBoxContainer.new()
	_cards_row.add_theme_constant_override("separation", ThemeService.min_spacing() * 2)
	_cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(_cards_row)

func on_start() -> void:
	_next_pair()

func _next_pair() -> void:
	if _queue.is_empty() or _finish_requested:
		_set_status(Strings.SUMMARY_DONE % _items_done)
		finish_session("completed")
		return
	var entry: Dictionary = _queue.pop_front()
	_current = entry["item"]
	_first_try = true
	_attempts = 0
	_item_start_ms = Time.get_ticks_msec()
	announce_item(str(_current.get("item_id", "")))
	_build_cards()
	_play_target()

# --- cartes : même taille, même style, toujours ---

func _build_cards() -> void:
	for c in _cards:
		ThemeService.gentle_release(c)
	_cards.clear()
	var cards: Array = _current.get("cards", [])
	var order: Array = _current.get("order", [])
	var indices: Array = []
	if order.size() == cards.size():
		for v in order:
			indices.append(int(v))
	else:
		for i in cards.size():
			indices.append(i)
	var n := cards.size()
	# taille identique pour toutes : calculée sur le nombre de cartes
	var usable := 984.0
	var spacing := ThemeService.min_spacing() * 2.0 * (n - 1)
	var card_w := (usable - spacing) / n
	card_w = minf(card_w, 440.0)
	card_w = maxf(card_w, ThemeService.min_touch_target())
	var card_h := minf(card_w * 1.1, 560.0)
	var written := _is_written_variant()
	for idx in indices:
		var card_data: Dictionary = cards[idx]
		var card := UIKit.tile("", Vector2(card_w, card_h))
		if written:
			# variante écrite (niveau 4) : le mot remplace l'image
			card.text = str(card_data.get("word", ""))
		else:
			card.text = str(card_data.get("word", ""))  # mot affiché ; l'image viendra de la plateforme
		var fs := Tuning.FONT_SIZE_TILE if card.text.length() <= 5 else Tuning.FONT_SIZE_TILE_SMALL
		card.add_theme_font_size_override("font_size", fs)
		var target_idx := int(_current.get("target_index", 0))
		if idx == target_idx:
			card.pressed.connect(_on_card_pressed.bind(idx, true))
		else:
			card.pressed.connect(_on_card_pressed.bind(idx, false))
		_cards_row.add_child(card)
		_cards.append(card)
		ThemeService.gentle_appear(card, (indices.find(idx)) * Tuning.FX_APPEAR_STAGGER_S)
	_set_status("")

func _is_written_variant() -> bool:
	return config.difficulty_level >= 4

# --- audio ---

func _play_target() -> void:
	var cards: Array = _current.get("cards", [])
	var ti := int(_current.get("target_index", 0))
	if ti < 0 or ti >= cards.size():
		return
	var audio: Dictionary = cards[ti].get("audio", {})
	AudioService.speak(str(_current.get("item_id", "")) + "_word", str(audio.get("word", "")), "word")

func _on_replay() -> void:
	SessionTimer.touch()
	Telemetry.emit_event("audio_replayed", {"item_id": str(_current.get("item_id", ""))})
	_play_target()

## Redit les deux mots lentement (à la fin d'une réponse, réussite ou erreur).
func _compare_both_words() -> void:
	var cards: Array = _current.get("cards", [])
	var first: String = str(cards[0].get("word", ""))
	var second: String = str(cards[1].get("word", "")) if cards.size() > 1 else ""
	_set_status(Strings.DUO_COMPARE % [first, second])
	# les audios "slow" de chaque mot, avec un léger silence entre les deux
	for i in cards.size():
		var audio: Dictionary = cards[i].get("audio", {})
		var slow := str(audio.get("slow", ""))
		if slow != "":
			AudioService.speak("%s_slow_%d" % [str(_current.get("item_id", "")), i], slow, "prompt")

# --- interactions ---

func _on_card_pressed(card_index: int, is_target: bool) -> void:
	SessionTimer.touch()
	if _finish_requested:
		return
	var cards: Array = _current.get("cards", [])
	var expected_word := str(cards[int(_current.get("target_index", 0))].get("word", ""))
	var chosen_word := str(cards[card_index].get("word", ""))
	_attempts += 1
	var detail := {
		"pair_id": str(_current.get("pair_id", "")),
		"chosen_word": chosen_word,
		"expected_word": expected_word,
		"contrast_label": str(_current.get("contrast_label", "")),
	}
	if is_target:
		var card: Button = _cards[_card_button_index(card_index)]
		var sb := StyleBoxFlat.new()
		sb.bg_color = ThemeService.GOOD_SOFT
		sb.border_color = ThemeService.GOOD
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(int(Tuning.UI_CORNER_RADIUS_SMALL))
		card.add_theme_stylebox_override("disabled", sb)
		card.add_theme_color_override("font_disabled_color", ThemeService.GOOD)
		card.disabled = true
		ThemeService.sparkle_burst(card, card.size * 0.5, ThemeService.GOOD)
		report_answer(str(_current.get("item_id", "")), true, detail, _attempts, Time.get_ticks_msec() - _item_start_ms)
		compare_both_words_safe()
		complete_item(str(_current.get("item_id", "")), _first_try, _attempts, 0)
		_set_status(Strings.DUO_SUCCESS % chosen_word)
		var timer := get_tree().create_timer(1.8)
		timer.timeout.connect(_next_pair)
	else:
		_first_try = false
		var card: Button = _cards[_card_button_index(card_index)]
		ThemeService.gentle_shake(card)
		report_answer(str(_current.get("item_id", "")), false, detail, _attempts, Time.get_ticks_msec() - _item_start_ms)
		_set_status(Strings.DUO_RETRY)
		compare_both_words_safe()
		_requeue_with_other_target()

func compare_both_words_safe() -> void:
	_compare_both_words()

func _card_button_index(card_index: int) -> int:
	# les cartes sont ajoutées dans l'ordre "indices" : retrouver le bouton correspondant
	var cards: Array = _current.get("cards", [])
	var order: Array = _current.get("order", [])
	var indices: Array = []
	if order.size() == cards.size():
		for v in order:
			indices.append(int(v))
	else:
		for i in cards.size():
			indices.append(i)
	for i in indices.size():
		if indices[i] == card_index:
			return i
	return 0

## Après une erreur, la paire revient plus tard avec l'AUTRE mot comme cible.
func _requeue_with_other_target() -> void:
	var cards: Array = _current.get("cards", [])
	var old_target := int(_current.get("target_index", 0))
	var new_target := 0 if old_target == 1 else 1
	if cards.size() > new_target:
		var item: Dictionary = _current.duplicate()
		item["target_index"] = new_target
		_queue.append({"item": item, "target": new_target})

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
