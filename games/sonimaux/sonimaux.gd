extends MiniGame
## Les Sonimaux (game_id : sonimaux) — aventure légère en 3 actes.
## Assemble les mini-jeux existants (chasse_sons, forge_mots, duo_mots) dans un épisode raconté
## avec une collection de créatures-sons. PAS un monde ouvert : pas de combat, pas de hasard,
## pas de perte. Le texte d'histoire est FOURNI ; le jeu REFUSE un épisode non safety_checked.
## Les stades des créatures sont DÉCIDÉS par la plateforme : le jeu les affiche.

signal episode_started(episode_id: String)
signal zone_started(zone_id: String)
signal zone_completed(zone_id: String)

var _story: Dictionary = {}
var _companion: Dictionary = {}
var _collection_state: Dictionary = {}
var _zones_done: Array = []
var _active_zone_game: MiniGame = null
var _phase: String = "intro"        # intro | map | zone | outro | rest | done
var _main_vb: VBoxContainer = null
var _status: Label = null
var _story_label: Label = null
var _buttons_box: VBoxContainer = null
var _carnet_btn: Button = null
var _pending_animations_done: bool = false
var _dots: ProgressDots = null
var _buddy: Buddy = null

func _setup(cfg: GameConfig) -> void:
	var errs := GameConfig.validate_sonimaux_config(cfg.raw)
	if not errs.is_empty():
		# refus propre : histoire non filtrée ou structure invalide → l'épisode ne démarre pas
		_finish_requested = true
		Bridge.send_error("story_unchecked" if str(errs[0]).contains("safety_checked") else "config_invalid", "; ".join(errs))
		show_error_screen("story_unchecked" if str(errs[0]).contains("safety_checked") else "config_invalid", "; ".join(errs))
		return
	_story = cfg.raw.get("story", {})
	_companion = cfg.raw.get("companion", {})
	_collection_state = cfg.raw.get("collection_state", {})
	# longueur max des lignes d'histoire selon l'âge
	var max_words := Tuning.SONIMAUX_LINE_MAX_WORDS_CHILD if config.age_band == "6-8" else Tuning.SONIMAUX_LINE_MAX_WORDS
	if _lines_too_long(max_words):
		show_error_screen("story_line_too_long", "Une ligne d'histoire dépasse la longueur maximale.")
		return
	_build_ui()
	start()

func _lines_too_long(max_words: int) -> bool:
	var groups: Array = [_story.get("intro_lines", []), _story.get("outro_lines", []), _story.get("rest_lines", [])]
	for zone in _story.get("zones", []):
		groups.append(zone.get("before_lines", []))
		groups.append(zone.get("after_lines", []))
	for group in groups:
		for line in group:
			if typeof(line) == TYPE_DICTIONARY:
				if str(line.get("text", "")).split(" ").size() > max_words:
					return true
	return false

func _build_ui() -> void:
	var backdrop := Backdrop.new()
	backdrop.setup("espace", _is_sober())
	add_child(backdrop)
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
	var title := Label.new()
	title.text = Strings.SONI_TITLE
	ThemeService.style_label(title, Tuning.FONT_SIZE_TITLE, ThemeService.INK, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(title)
	_buddy = Buddy.new()
	_buddy.set_sober(_is_sober())
	_buddy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_buddy)
	top.add_child(build_time_gauge())

	_story_label = Label.new()
	_story_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_story_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_story_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ThemeService.style_label(_story_label, Tuning.FONT_SIZE_BODY, ThemeService.INK, true)
	_main_vb.add_child(_story_label)

	# progression calme : une pastille par zone de l'épisode
	var dots_wrap := CenterContainer.new()
	_dots = ProgressDots.new()
	_dots.setup(maxi(_story.get("zones", []).size(), 1))
	dots_wrap.add_child(_dots)
	_main_vb.add_child(dots_wrap)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeService.style_label(_status, int(Tuning.FONT_SIZE_BODY * 0.8), ThemeService.INK_SOFT)
	_main_vb.add_child(_status)

	_buttons_box = VBoxContainer.new()
	_buttons_box.add_theme_constant_override("separation", 12)
	_buttons_box.alignment = BoxContainer.ALIGNMENT_END
	_main_vb.add_child(_buttons_box)
	_carnet_btn = UIKit.big_button(Strings.CARNET, _open_carnet)
	_buttons_box.add_child(_carnet_btn)

func on_start() -> void:
	Telemetry.emit_event("episode_started", {"episode_id": str(_story.get("episode_id", ""))})
	_play_intro()

# --- acte 1 : intro ---

func _play_intro() -> void:
	_phase = "intro"
	_play_lines(_story.get("intro_lines", []), _show_map)

# --- acte 2 : carte des zones ---

func _show_map() -> void:
	_phase = "map"
	# jouer les animations d'évolution en attente au début de la partie (1 seule fois)
	if not _pending_animations_done:
		_pending_animations_done = true
		_play_pending_animations()
	_story_label.text = "%s\n\n%s" % [str(_story.get("title", "")), _zones_summary()]
	for c in _buttons_box.get_children():
		if c != _carnet_btn:
			c.queue_free()
	for zone in _story.get("zones", []):
		var zone_id := str(zone.get("zone_id", ""))
		if _zones_done.has(zone_id):
			continue
		var btn := UIKit.big_button(Strings.SONI_ZONE_START % str(zone.get("label", "")), _start_zone.bind(zone.duplicate()))
		_buttons_box.add_child(btn)
	if _all_zones_done():
		_play_outro()

func _zones_summary() -> String:
	var total: int = _story.get("zones", []).size()
	return "%d / %d zones explorées" % [_zones_done.size(), total]

func _all_zones_done() -> bool:
	return _zones_done.size() >= _story.get("zones", []).size()

func _start_zone(zone: Dictionary) -> void:
	SessionTimer.touch()
	var zone_id := str(zone.get("zone_id", ""))
	var game_id := str(zone.get("game_id", ""))
	_phase = "zone"
	Telemetry.emit_event("zone_started", {"zone_id": zone_id, "game_id": game_id})
	zone_started.emit(zone_id)
	# lignes d'histoire AVANT le mini-jeu
	_play_lines(zone.get("before_lines", []), func() -> void: _launch_zone_game(zone))

func _launch_zone_game(zone: Dictionary) -> void:
	var zone_id := str(zone.get("zone_id", ""))
	var game_config: Dictionary = zone.get("game_config", {})
	if game_config.is_empty():
		_zone_finished(zone)
		return
	# instancier le mini-jeu ciblé avec SA configuration (champ game_config)
	var game_id := str(zone.get("game_id", ""))
	var path := ""
	match game_id:
		"chasse_sons":
			path = "res://games/chasse_sons/chasse_sons.tscn"
		"forge_mots":
			path = "res://games/forge_mots/forge_mots.tscn"
		"duo_mots":
			path = "res://games/duo_mots/duo_mots.tscn"
		_:
			Bridge.send_error("zone_game_unknown", "Mini-jeu inconnu dans la zone : %s" % game_id)
			_zone_finished(zone)
			return
	var packed: PackedScene = load(path)
	var game := packed.instantiate()
	if not game is MiniGame:
		Bridge.send_error("zone_game_invalid", "La scène %s n'hérite pas de MiniGame" % path)
		_zone_finished(zone)
		return
	var cfg := GameConfig.new(game_config)
	if not cfg.validity:
		Bridge.send_error("zone_config_invalid", "Configuration de zone invalide : %s" % zone_id)
		_zone_finished(zone)
		return
	# le mini-jeu remplace l'affichage de l'aventure (les événements sont transmis tels quels)
	_story_label.text = ""
	for c in _buttons_box.get_children():
		c.visible = false
	add_child(game)
	_active_zone_game = game
	game.setup(cfg)
	game.start()
	game.game_completed.connect(func(summary: Dictionary) -> void:
		_zone_finished(zone))

func _zone_finished(zone: Dictionary) -> void:
	var zone_id := str(zone.get("zone_id", ""))
	if not _zones_done.has(zone_id):
		_zones_done.append(zone_id)
	_dots.light_next()
	Sfx.pair_bell()
	if _buddy != null:
		_buddy.react(Buddy.Mood.HAPPY, Strings.BUDDY_CHEER)
	Telemetry.emit_event("zone_completed", {"zone_id": zone_id, "items_done": _items_done})
	zone_completed.emit(zone_id)
	if _active_zone_game != null:
		_active_zone_game.queue_free()
		_active_zone_game = null
	for c in _buttons_box.get_children():
		c.visible = true
	# lignes d'histoire APRÈS le mini-jeu + remerciement du compagnon
	_play_lines(zone.get("after_lines", []), _thank_after_zone)

func _thank_after_zone() -> void:
	_set_status(Strings.SONI_THANKS)
	var timer := get_tree().create_timer(1.2)
	timer.timeout.connect(_after_zone_continue)

func _after_zone_continue() -> void:
	if _all_zones_done():
		_play_outro()
	else:
		_show_map()

# --- acte 3 : conclusion et repos ---

func _play_outro() -> void:
	_phase = "outro"
	_play_lines(_story.get("outro_lines", []), _play_rest)

func _play_rest() -> void:
	_phase = "rest"
	_play_lines(_story.get("rest_lines", []), _finish_episode)

func _finish_episode() -> void:
	Telemetry.emit_event("episode_ended", {"reason": "completed", "zones_done": _zones_done})
	_set_status(Strings.SONI_EPISODE_END)
	finish_session("completed")

# --- lecture des lignes (audio fourni pour chaque ligne) ---

func _play_lines(lines: Array, on_done: Callable) -> void:
	if lines.is_empty():
		on_done.call()
		return
	_play_next_line(lines, 0, on_done)

func _play_next_line(lines: Array, index: int, on_done: Callable) -> void:
	if not is_inside_tree():
		return
	if index >= lines.size():
		on_done.call()
		return
	var line: Dictionary = lines[index] if typeof(lines[index]) == TYPE_DICTIONARY else {}
	_story_label.text = str(line.get("text", ""))
	AudioService.speak("story_%d" % index, str(line.get("audio", "")), "prompt")
	var timer := get_tree().create_timer(2.2)
	timer.timeout.connect(_play_next_line.bind(lines, index + 1, on_done))

# --- carnet des Sonimaux ---

func _open_carnet() -> void:
	SessionTimer.touch()
	Telemetry.emit_event("carnet_opened", {})
	var carnet := CarnetScreen.build(_collection_state, config.age_band)
	add_child(carnet)

# --- évolutions en attente (décidées par la plateforme) ---

func _play_pending_animations() -> void:
	var pending: Array = _collection_state.get("pending_animations", [])
	for anim in pending:
		var creature_id := str(anim.get("creature_id", ""))
		var creature_name := _creature_name(creature_id)
		Telemetry.emit_event("creature_evolved", {"creature_id": creature_id, "from_stage": int(anim.get("from_stage", 0)), "to_stage": int(anim.get("to_stage", 0))})
		_set_status(Strings.SONI_EVOLVE % creature_name)
	# les stades affichés dans le carnet reflètent l'état envoyé par la plateforme (déjà à jour)

func _creature_name(creature_id: String) -> String:
	for c in _collection_state.get("creatures", []):
		if str(c.get("creature_id", "")) == creature_id:
			return str(c.get("name", ""))
	return ""

func _set_status(text: String) -> void:
	if _status != null:
		_status.text = text

func _is_sober() -> bool:
	return ThemeService.age_band == "12-14" or ThemeService.age_band == "15-16"

func on_pause() -> void:
	SessionTimer.pause()
	if _active_zone_game != null:
		_active_zone_game.on_pause()

func on_resume() -> void:
	SessionTimer.resume()
	if _active_zone_game != null:
		_active_zone_game.on_resume()

func on_time_soft_end() -> void:
	# on termine l'épreuve en cours puis scène de repos
	if _active_zone_game != null:
		await _active_zone_game.game_completed
	_play_rest()

func on_time_limit() -> void:
	if _active_zone_game != null:
		_active_zone_game.queue_free()
		_active_zone_game = null
	Telemetry.emit_event("episode_ended", {"reason": "time_limit", "zones_done": _zones_done})
	finish_session("time_limit")
