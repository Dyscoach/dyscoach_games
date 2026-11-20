## Tests Syllabo : validation config, comptage (frappes = wagons), réussite, erreur + réessai,
## réinsertion après 2 échecs, découpage fourni (jamais calculé), validation auto.
## Booter : godot --headless --path . res://tests/test_syllabo.tscn
extends Node

var _failures: Array[String] = []
var _passes: int = 0

func _ready() -> void:
	await get_tree().process_frame
	Telemetry.reset()
	await _test_config_valid()
	await _test_drum_wagons()
	await _test_correct_word()
	await _test_wrong_then_retry_then_requeue()
	_finish()

func check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
	else:
		_failures.append(label)
		push_error("FAIL : " + label)

func _load() -> Dictionary:
	var f := FileAccess.open("res://dev/config_syllabo.json", FileAccess.READ)
	return JSON.parse_string(f.get_as_text())

func _test_config_valid() -> void:
	var data := _load()
	check(data != null, "config syllabo parsée")
	var cfg := GameConfig.new(data)
	check(cfg.validity, "config syllabo valide")
	var errs := GameConfig.validate_syllabo_items(data["items"])
	check(errs.is_empty(), "items syllabo valides : %s" % str(errs))
	check(cfg.item_count() == 9, "9 mots d'essai (bus → kangourou)")
	# mots du document présents avec les comptes attendus
	var expected := {"bus": 1, "vélo": 2, "bateau": 2, "lapin": 2, "ballon": 2, "papillon": 3, "chocolat": 3, "éléphant": 3, "kangourou": 3}
	for it in data["items"]:
		var w := str(it["word"])
		check(int(it["syllable_count"]) == expected[w], "syllable_count conforme pour %s (%d)" % [w, int(it["syllable_count"])])
		check(int(it["syllable_count"]) == it["syllables"].size(), "découpage cohérent pour " + w)

func _test_drum_wagons() -> void:
	var game = load("res://games/syllabo/syllabo.tscn").instantiate()
	add_child(game)
	var cfg := GameConfig.new(_load())
	game.setup(cfg)
	await get_tree().process_frame
	await get_tree().process_frame
	check(str(game._current.get("word")) == "bus", "1er mot = bus")
	# 1 frappe = 1 wagon : le nombre de wagons suit EXACTEMENT les touchers
	for i in 3:
		game._on_drum()
		await get_tree().process_frame
	check(game._tapped_count == 3, "3 frappes comptées")
	check(game._train_box.get_child_count() == 3, "3 wagons apparus (exactement le nombre de touchers)")
	game.queue_free()

func _test_correct_word() -> void:
	var game = load("res://games/syllabo/syllabo.tscn").instantiate()
	add_child(game)
	var cfg := GameConfig.new(_load())
	game.setup(cfg)
	await get_tree().process_frame
	await get_tree().process_frame
	Telemetry.reset()
	var answers := []
	var completed := []
	game.item_answered.connect(func(id: String, correct: bool, detail: Dictionary) -> void: answers.append({"id": id, "c": correct, "d": detail}))
	game.item_completed.connect(func(id: String) -> void: completed.append(id))
	# bus = 1 syllabe : 1 frappe puis validation bouton
	game._on_drum()
	await get_tree().process_frame
	game._on_finish_pressed()
	await get_tree().process_frame
	check(not answers.is_empty() and bool(answers[0]["c"]), "bus : réponse correcte enregistrée")
	var d: Dictionary = answers[0]["d"]
	check(int(d.get("expected_count")) == 1 and int(d.get("tapped_count")) == 1 and d.has("auto_validated"), "detail conforme {expected_count, tapped_count, auto_validated}")
	check(not completed.is_empty(), "item_completed émis pour bus")
	game.queue_free()

func _test_wrong_then_retry_then_requeue() -> void:
	var game = load("res://games/syllabo/syllabo.tscn").instantiate()
	add_child(game)
	var cfg := GameConfig.new(_load())
	game.setup(cfg)
	await get_tree().process_frame
	await get_tree().process_frame
	# bus : mauvaise réponse (2 frappes), réessai raté (2 frappes) → réinsertion
	game._on_drum()
	game._on_drum()
	await get_tree().process_frame
	game._on_finish_pressed()   # 2 != 1 → erreur, nouvel essai
	await get_tree().create_timer(2.6).timeout
	check(game._tapped_count == 0, "le train est vidé pour le nouvel essai")
	var queue_size: int = game._queue.size()
	game._on_drum()
	game._on_drum()
	await get_tree().process_frame
	game._on_finish_pressed()   # 2e échec → réinsertion + mot suivant
	await get_tree().create_timer(2.8).timeout
	var bus_requeued := false
	for entry in game._queue:
		if str(entry.get("word", "")) == "bus":
			bus_requeued = true
	check(bus_requeued, "bus réinséré pour plus tard après 2 essais")
	check(str(game._current.get("word")) == "vélo", "passage au mot suivant (vélo)")

	# brique DA : décor d'univers + mascotte présents
	var _da_found := false
	for c in game.get_children():
		if c is Backdrop:
			_da_found = true
			check(c.universe == "campagne", "décor campagne appliqué")
	check(_da_found, "décor Backdrop présent")
	check(game._buddy != null and game._buddy is Buddy, "mascotte Buddy instanciée")
	game.queue_free()

func _finish() -> void:
	if _failures.is_empty():
		print("TESTS SYLLABO OK : %d vérifications" % _passes)
		get_tree().quit(0)
	else:
		print("TESTS SYLLABO ÉCHOUÉS : %d — %s" % [_failures.size(), "; ".join(_failures)])
		get_tree().quit(1)
