## Tests Duo-Mots : validation config, cartes de même taille, ordre fixe, erreur → l'autre cible,
## comparaison des deux mots, image manquante (carte neutre + error).
## Booter : godot --headless --path . res://tests/test_duo_mots.tscn
extends Node

var _failures: Array[String] = []
var _passes: int = 0

func _ready() -> void:
	await get_tree().process_frame
	Telemetry.reset()
	await _test_config_valid()
	await _test_cards_same_size()
	await _test_error_requeues_other_target()
	await _test_events_conformity()
	_finish()

func check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
	else:
		_failures.append(label)
		push_error("FAIL : " + label)

func _load() -> Dictionary:
	var f := FileAccess.open("res://dev/config_duo_mots.json", FileAccess.READ)
	return JSON.parse_string(f.get_as_text())

func _test_config_valid() -> void:
	var data := _load()
	check(data != null, "config duo parsée")
	var cfg := GameConfig.new(data)
	check(cfg.validity, "config duo valide")
	var errs := GameConfig.validate_duo_items(data["items"])
	check(errs.is_empty(), "items duo valides : %s" % str(errs))
	check(cfg.item_count() == 6, "6 paires d'essai")
	# paires du document présentes
	var pairs := []
	for it in data["items"]:
		pairs.append(str(it["pair_id"]))
	for expected in ["pair_chat_rat", "pair_poule_boule", "pair_pain_bain", "pair_mer_ver", "pair_mouton_bouton", "pair_lit_riz"]:
		check(pairs.has(expected), "paire présente : " + expected)
	# une carte sans image (cas limite du document : carte neutre + error)
	var missing_img := false
	for it in data["items"]:
		for c in it["cards"]:
			if str(c.get("image_id", "")) == "":
				missing_img = true
	check(missing_img, "une carte avec image manquante (cas limite couvert)")
	# lit/riz : order inversé [1,0] pour la reproductibilité
	var lit: Dictionary = {}
	for it in data["items"]:
		if str(it["pair_id"]) == "pair_lit_riz":
			lit = it
	var order: Array = lit.get("order", [])
	check(order.size() == 2 and int(order[0]) == 1 and int(order[1]) == 0, "order fixe [1,0] sur lit/riz (reproductible)")

func _test_cards_same_size() -> void:
	var cfg := GameConfig.new(_load())
	var game = load("res://games/duo_mots/duo_mots.tscn").instantiate()
	add_child(game)
	game.setup(cfg)
	await get_tree().process_frame
	await get_tree().process_frame
	check(game._cards.size() == 2, "2 cartes affichées (niveau 1)")
	var sizes := []
	for c in game._cards:
		sizes.append(c.custom_minimum_size)
	check(sizes[0] == sizes[1], "les deux cartes ont EXACTEMENT la même taille (%s vs %s)" % [str(sizes[0]), str(sizes[1])])
	check(sizes[0].x >= ThemeService.min_touch_target(), "carte >= cible tactile minimale")
	game.queue_free()

func _test_error_requeues_other_target() -> void:
	var cfg := GameConfig.new(_load())
	var game = load("res://games/duo_mots/duo_mots.tscn").instantiate()
	add_child(game)
	game.setup(cfg)
	await get_tree().process_frame
	await get_tree().process_frame
	# paire 1 : chat (cible 0). Toucher rat (index 1, non-cible) = erreur
	var queue_before: int = game._queue.size()
	game._on_card_pressed(1, false)
	await get_tree().process_frame
	check(game._queue.size() == queue_before + 1, "après erreur, la paire revient dans la file")
	var requeued: Dictionary = game._queue[game._queue.size() - 1]["item"]
	check(int(requeued.get("target_index", -1)) == 1, "la paire revient avec l'AUTRE mot comme cible (rat)")
	# statut ECAR : les deux mots redits
	check(game._status.text.contains("Presque") or game._status.text.contains("Les deux mots"), "retour ECAR affiché")
	game.queue_free()

func _test_events_conformity() -> void:
	var cfg := GameConfig.new(_load())
	var game = load("res://games/duo_mots/duo_mots.tscn").instantiate()
	add_child(game)
	game.setup(cfg)
	await get_tree().process_frame
	await get_tree().process_frame
	Telemetry.reset()
	var answers := []
	game.item_answered.connect(func(id: String, correct: bool, detail: Dictionary) -> void:
		answers.append({"id": id, "correct": correct, "detail": detail}))
	# toucher la bonne carte (chat = cible index 0)
	game._on_card_pressed(0, true)
	await get_tree().process_frame
	check(not answers.is_empty(), "item_answered émis")
	if not answers.is_empty():
		check(bool(answers[0]["correct"]), "bonne carte → correct")
		var d: Dictionary = answers[0]["detail"]
		check(str(d.get("pair_id")) == "pair_chat_rat" and str(d.get("chosen_word")) == "chat" and str(d.get("expected_word")) == "chat", "detail conforme {pair_id, chosen_word, expected_word, contrast_label}")
		check(d.has("contrast_label"), "contrast_label présent")
	game.queue_free()

func _finish() -> void:
	if _failures.is_empty():
		print("TESTS DUO-MOTS OK : %d vérifications" % _passes)
		get_tree().quit(0)
	else:
		print("TESTS DUO-MOTS ÉCHOUÉS : %d — %s" % [_failures.size(), "; ".join(_failures)])
		get_tree().quit(1)
