extends MiniGame
## Mémo-Mots (game_id : memo_mots) — jeu de paires.
## Retrouver les paires mot-image (ou homophone-phrase au niveau 3) parmi des cartes retournées.
## Chaque retournement lit le mot à voix haute. Aucun chrono, aucun compteur de coups visible.
## La plateforme choisit les mots à revoir (due_reason 1/3/7 jours) ; le jeu n'en choisit aucun.

var _items: Array = []
var _cards: Array = []                # MemoCard instanciées
var _first_flipped: int = -1          # index de la 1re carte retournée
var _lock_input: bool = false
var _matched_pairs: int = 0
var _flips_count: int = 0
var _main_vb: VBoxContainer = null
var _grid: GridContainer = null
var _status: Label = null

func _setup(cfg: GameConfig) -> void:
	var errs := GameConfig.validate_memo_items(cfg.items)
	if not errs.is_empty():
		show_error_screen("config_invalid", "; ".join(errs))
		return
	# nombre de paires selon le niveau (1 = 4, 2 = 6, 3 = homophones) et l'écran
	var want: int = Tuning.MEMO_CARDS_LEVEL1 if cfg.difficulty_level <= 1 else Tuning.MEMO_CARDS_LEVEL2
	_items = cfg.items.slice(0, want)
	_build_ui()
	start()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = ThemeService.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)
	_main_vb = VBoxContainer.new()
	_main_vb.add_theme_constant_override("separation", 16)
	margin.add_child(_main_vb)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	_main_vb.add_child(top)
	var title := Label.new()
	title.text = Strings.MEMO_TITLE
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
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", ThemeService.min_spacing())
	_grid.add_theme_constant_override("v_separation", ThemeService.min_spacing())
	_grid.columns = _columns_for_pairs()
	center.add_child(_grid)
	_deal_cards()

func _columns_for_pairs() -> int:
	var n := _items.size()
	# 4 paires → 4 colonnes ; 6 paires → 4 colonnes (2 rangées) ; petit écran → réduit
	return 4 if n <= 4 else 4

func _deal_cards() -> void:
	# chaque paire → 2 cartes (card_a, card_b), ordre de disposition mélangé localement
	var entries: Array = []
	for it in _items:
		entries.append({"item": it, "side": "a"})
		entries.append({"item": it, "side": "b"})
	var display: Array = entries.duplicate()
	display.shuffle()
	for e in display:
		var card := MemoCard.new_card(e["item"], str(e["side"]))
		card.card_flipped.connect(_on_card_flipped)
		_grid.add_child(card)
		_cards.append(card)

# --- retournements ---

func _on_card_flipped(card: MemoCard) -> void:
	if _lock_input or card.is_matched:
		return
	SessionTimer.touch()
	card.flip_up()
	_flips_count += 1
	# chaque carte retournée est lue à voix haute
	_read_card(card)
	var idx := _cards.find(card)
	if _first_flipped < 0:
		_first_flipped = idx
		return
	# 2e carte : comparer
	var first: MemoCard = _cards[_first_flipped]
	var first_try: bool = _flips_count == 2
	if first.pair_id() == card.pair_id() and first != card:
		# paire trouvée : illuminer puis s'éloigner doucement
		_matched_pairs += 1
		first.mark_matched()
		card.mark_matched()
		ThemeService.sparkle_burst(first, first.size * 0.5, ThemeService.GOOD)
		ThemeService.sparkle_burst(card, card.size * 0.5, ThemeService.GOOD)
		var item_id := str((first.data).get("item_id", ""))
		report_answer(item_id, true, {"pair_id": first.pair_id(), "kind": str(first.data.get("kind", "word_image")), "flips_to_match": _flips_count}, 1, 0)
		complete_item(item_id, first_try, maxi(_flips_count / 2, 1), 0)
		_items_done += 1
		_set_status(Strings.MEMO_FOUND % first.display_word())
		_first_flipped = -1
		_flips_count = 0
		if _matched_pairs >= _items.size():
			_all_matched()
	else:
		# pas une paire : se retournent doucement, sans pénalité
		_lock_input = true
		_set_status(Strings.MEMO_RETRY)
		var timer := get_tree().create_timer(Tuning.MEMO_FLIP_BACK_MS / 1000.0)
		timer.timeout.connect(func() -> void:
			first.flip_down()
			card.flip_down()
			_lock_input = false
			_first_flipped = -1
			_flips_count = 0)

func _read_card(card: MemoCard) -> void:
	var audio: Dictionary = card.audio_urls()
	AudioService.speak("%s_%s_read" % [card.pair_id(), card.side], str(audio.get("word", "")), "word")

func _all_matched() -> void:
	_set_status(Strings.SUCCESS_BRAVO)
	var timer := get_tree().create_timer(1.6)
	timer.timeout.connect(func() -> void:
		_set_status(Strings.SUMMARY_DONE % _items_done)
		finish_session("completed"))

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
