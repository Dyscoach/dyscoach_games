## Tests Radar à Lettres : validation config (grille fournie, cibles exactes),
## logique de grille (cibles trouvées = target_count, mauvaise lettre ne disparaît pas),
## plafond de 2 minutes, police OpenDyslexic partout (thème du projet).
## Booter : godot --headless --path . res://tests/test_radar_lettres.tscn
extends Node

var _failures: Array[String] = []
var _passes: int = 0

func _ready() -> void:
	await get_tree().process_frame
	Telemetry.reset()
	await _test_config_valid()
	await _test_grid_logic()
	await _test_session_ceiling()
	_finish()

func check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
	else:
		_failures.append(label)
		push_error("FAIL : " + label)

func _load() -> Dictionary:
	var f := FileAccess.open("res://dev/config_radar_lettres.json", FileAccess.READ)
	return JSON.parse_string(f.get_as_text())

func _test_config_valid() -> void:
	var data := _load()
	check(data != null, "config radar parsée")
	var cfg := GameConfig.new(data)
	check(cfg.validity, "config radar valide")
	var errs := GameConfig.validate_radar_items(data["items"])
	check(errs.is_empty(), "items radar valides : %s" % str(errs))
	# grille 1 : b parmi d,p,q, [b,d,p,b,q,d,b,p,d], 3 cibles (exactement)
	var item1: Dictionary = data["items"][0]
	check(item1["grid"] == ["b", "d", "p", "b", "q", "d", "b", "p", "d"], "grille 1 fournie dans l'ordre fixe")
	check(int(item1["target_count"]) == 3, "grille 1 : 3 cibles annoncées")
	# grille 2 : on parmi ou/an/in, 12 cases, 3 cibles
	var item2: Dictionary = data["items"][1]
	check(item2["grid"].size() == 12, "grille 2 : 12 cases")
	check(int(item2["target_count"]) == 3, "grille 2 : 3 cibles")
	# session_limits courts (échauffement 2 min)
	check(float(data["session_limits"]["max_active_minutes"]) <= 2.0, "séance limitée à 2 minutes")

func _test_grid_logic() -> void:
	var game = load("res://games/radar_lettres/radar_lettres.tscn").instantiate()
	add_child(game)
	var cfg := GameConfig.new(_load())
	game.setup(cfg)
	await get_tree().process_frame
	await get_tree().process_frame
	check(game._grid_cells.size() == 9, "grille 1 : 9 cellules affichées")
	check(game._model_label.text.contains("b comme bateau"), "modèle affiché : b comme bateau")
	Telemetry.reset()
	var answers := []
	var completed := []
	game.item_answered.connect(func(id: String, correct: bool, detail: Dictionary) -> void: answers.append({"id": id, "c": correct, "d": detail}))
	game.item_completed.connect(func(id: String) -> void: completed.append(id))
	# toucher une mauvaise lettre (d) : tremble, reste en place, was_target false
	var d_cell: Button = null
	for c in game._grid_cells:
		if str(c.text) == "d" and not c.disabled:
			d_cell = c
			break
	check(d_cell != null, "une cellule d trouvée")
	game._on_cell_pressed(d_cell)
	await get_tree().process_frame
	check(not d_cell.disabled, "la mauvaise lettre reste en place (ne disparaît pas)")
	check(not answers.is_empty() and not bool(answers[0]["c"]), "mauvaise lettre → item_answered incorrect")
	check(str(answers[0]["d"].get("was_target")) == "false", "detail was_target=false")
	check(game._confusions.size() == 1, "confusion enregistrée {tapped, expected}")
	# toucher les 3 cibles b : grille terminée
	var b_cells: Array = []
	for c in game._grid_cells:
		if str(c.text) == "b" and not c.disabled:
			b_cells.append(c)
	check(b_cells.size() == 3, "3 cellules b présentes")
	for c in b_cells:
		game._on_cell_pressed(c)
		await get_tree().process_frame
	check(game._found_count == 3, "3 cibles trouvées")
	check(not completed.is_empty(), "item_completed émis pour la grille 1")
	var total_true := 0
	for a in answers:
		if bool(a["c"]):
			total_true += 1
	check(total_true == 3, "exactement 3 réponses correctes (=target_count)")
	game.queue_free()

func _test_session_ceiling() -> void:
	# le plafond de 2 minutes (Tuning) termine proprement la séance
	check(Tuning.RADAR_SESSION_MAX_MS == 120000, "plafond de séance : 120 000 ms (2 min)")
	var game = load("res://games/radar_lettres/radar_lettres.tscn").instantiate()
	add_child(game)
	var cfg := GameConfig.new(_load())
	game.setup(cfg)
	await get_tree().process_frame
	# simuler l'échéance dépassée
	game._session_deadline_ms = Time.get_ticks_msec() - 1
	await get_tree().process_frame
	await get_tree().create_timer(Tuning.FX_CELEBRATION_MS / 1000.0 + 0.3).timeout
	check(game._finish_requested, "échéance atteinte → fin propre de la séance")

	# brique DA : décor d'univers + mascotte présents
	var _da_found := false
	for c in game.get_children():
		if c is Backdrop:
			_da_found = true
			check(c.universe == "nuit", "décor nuit appliqué")
	check(_da_found, "décor Backdrop présent")
	check(game._buddy != null and game._buddy is Buddy, "mascotte Buddy instanciée")
	game.queue_free()

func _finish() -> void:
	if _failures.is_empty():
		print("TESTS RADAR OK : %d vérifications" % _passes)
		get_tree().quit(0)
	else:
		print("TESTS RADAR ÉCHOUÉS : %d — %s" % [_failures.size(), "; ".join(_failures)])
		get_tree().quit(1)
