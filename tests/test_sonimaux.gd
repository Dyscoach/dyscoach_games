## Tests Les Sonimaux : refus d'histoire non filtrée, validation d'épisode, carnet = stades
## exacts de la configuration, animations en attente, enchaînement des zones.
## Booter : godot --headless --path . res://tests/test_sonimaux.tscn
extends Node

var _failures: Array[String] = []
var _passes: int = 0

func _ready() -> void:
	await get_tree().process_frame
	Telemetry.reset()
	await _test_unchecked_story_refused()
	await _test_episode_structure()
	await _test_carnet_reflects_config()
	await _test_pending_animation()
	await _test_zone_launch()
	_finish()

func check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
	else:
		_failures.append(label)
		push_error("FAIL : " + label)

func _load(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	return JSON.parse_string(f.get_as_text())

# --- l'épisode avec safety_checked=false est REFUSÉ proprement ---
func _test_unchecked_story_refused() -> void:
	var cfg := GameConfig.new(_load("res://dev/config_sonimaux_unsafe.json"))
	check(cfg.validity, "config unsafe : champs communs valides")
	var errs := GameConfig.validate_sonimaux_config(cfg.raw)
	check(not errs.is_empty(), "refus détecté en validation")
	var refused := false
	for e in errs:
		if str(e).contains("safety_checked"):
			refused = true
	check(refused, "motif du refus : story.safety_checked est faux")

	# le jeu affiche l'écran d'erreur et n'affiche AUCUNE ligne d'histoire
	var game = load("res://games/sonimaux/sonimaux.tscn").instantiate()
	add_child(game)
	game.setup(cfg)
	await get_tree().process_frame
	await get_tree().process_frame
	check(game._story.is_empty(), "histoire NON chargée (refusée)")
	check(game._finish_requested, "l'épisode refusé ne démarre pas")
	game.queue_free()

# --- structure de l'épisode d'essai ---
func _test_episode_structure() -> void:
	var cfg := GameConfig.new(_load("res://dev/config_sonimaux.json"))
	var errs := GameConfig.validate_sonimaux_config(cfg.raw)
	check(errs.is_empty(), "épisode d'essai valide : %s" % str(errs))
	var story: Dictionary = cfg.raw["story"]
	check(story["intro_lines"].size() == 2, "intro de 2 lignes")
	check(story["zones"].size() == 3, "3 zones (chasse_sons, forge_mots, duo_mots)")
	var game_ids := []
	for z in story["zones"]:
		game_ids.append(str(z["game_id"]))
		check(not z["game_config"].is_empty(), "zone avec sa propre game_config")
	check(game_ids == ["chasse_sons", "forge_mots", "duo_mots"], "zones = chasse_sons / forge_mots / duo_mots")
	check(story["outro_lines"].size() == 2, "conclusion de 2 lignes")
	check(story["rest_lines"].size() == 1, "repos de 1 ligne")
	# longueur des lignes ≤ 20 mots (9 ans et plus)
	for line in story["intro_lines"]:
		check(str(line["text"]).split(" ").size() <= Tuning.SONIMAUX_LINE_MAX_WORDS, "ligne d'intro ≤ 20 mots")

# --- le carnet reflète EXACTEMENT les stades de la configuration ---
func _test_carnet_reflects_config() -> void:
	var cfg := GameConfig.new(_load("res://dev/config_sonimaux.json"))
	var game = load("res://games/sonimaux/sonimaux.tscn").instantiate()
	add_child(game)
	game.setup(cfg)
	await get_tree().process_frame
	await get_tree().process_frame
	var creatures: Array = game._collection_state.get("creatures", [])
	check(creatures.size() == 8, "8 créatures de départ (Bibi → Ouki)")
	# Bibi stade 1 (œuf), les autres stade 0 (silhouette) — exactement la config
	var stages := {}
	for c in creatures:
		stages[str(c["creature_id"])] = int(c["stage"])
	check(int(stages.get("bibi", -1)) == 1, "Bibi stade 1 (œuf) exactement comme envoyé")
	for cid in ["dodo", "pipo", "toti", "fifou", "vivi", "chachi", "ouki"]:
		check(int(stages.get(cid, -1)) == 0, cid + " stade 0 (silhouette)")
	# le carnet construit depuis collection_state affiche ces mêmes stades
	var carnet: Control = load("res://games/sonimaux/carnet_screen.gd").build(game._collection_state, "9-11")
	check(carnet != null, "carnet construit")
	carnet.queue_free()
	game.queue_free()

# --- animations d'évolution en attente ---
func _test_pending_animation() -> void:
	var cfg := GameConfig.new(_load("res://dev/config_sonimaux.json"))
	var game = load("res://games/sonimaux/sonimaux.tscn").instantiate()
	add_child(game)
	Telemetry.reset()
	game.setup(cfg)
	await get_tree().process_frame
	await get_tree().process_frame
	# le jeu joue les pending_animations au début de la partie (au passage à la carte)
	game._pending_animations_done = false
	game._play_pending_animations()
	var evolved := false
	for ev in Telemetry.log_snapshot():
		if str(ev.get("name")) == "creature_evolved":
			evolved = true
	check(evolved, "pending_animation jouée (creature_evolved émis)")
	check(game._status.text.contains("Bibi"), "message d'évolution nomme la créature (Bibi)")
	game.queue_free()

# --- enchaînement des zones : lancer une zone instancie le bon mini-jeu ---
func _test_zone_launch() -> void:
	var cfg := GameConfig.new(_load("res://dev/config_sonimaux.json"))
	var game = load("res://games/sonimaux/sonimaux.tscn").instantiate()
	add_child(game)
	game.setup(cfg)
	await get_tree().process_frame
	await get_tree().process_frame
	# passer directement à la zone 1 (chasse_sons)
	var zone1: Dictionary = game._story["zones"][0]
	game._launch_zone_game(zone1)
	await get_tree().process_frame
	await get_tree().process_frame
	check(game._active_zone_game != null, "mini-jeu de zone instancié")
	if game._active_zone_game != null:
		check(str(game._active_zone_game.get_script().resource_path).contains("chasse_sons"), "zone 1 = Chasse-Sons")
		check(game._active_zone_game._round_items.size() >= 2, "le mini-jeu a reçu sa propre configuration")
		# terminer la zone
		game._zone_finished(zone1)
		await get_tree().process_frame
		check(game._zones_done.has("zone_radar"), "zone_radar marquée terminée")
		check(game._active_zone_game == null, "mini-jeu de zone libéré")
	game.queue_free()

func _finish() -> void:
	if _failures.is_empty():
		print("TESTS SONIMAUX OK : %d vérifications" % _passes)
		get_tree().quit(0)
	else:
		print("TESTS SONIMAUX ÉCHOUÉS : %d — %s" % [_failures.size(), "; ".join(_failures)])
		get_tree().quit(1)
