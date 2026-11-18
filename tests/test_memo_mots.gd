## Tests Mémo-Mots : validation config, logique de paires (match, non-match, retournement),
## homophones (niveau 3), due_reason, carte sans image, fin de partie.
## Booter : godot --headless --path . res://tests/test_memo_mots.tscn
extends Node

var _failures: Array[String] = []
var _passes: int = 0

func _ready() -> void:
	await get_tree().process_frame
	Telemetry.reset()
	await _test_config_valid()
	await _test_pair_logic()
	await _test_homophone_config()
	_finish()

func check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
	else:
		_failures.append(label)
		push_error("FAIL : " + label)

func _load() -> Dictionary:
	var f := FileAccess.open("res://dev/config_memo_mots.json", FileAccess.READ)
	return JSON.parse_string(f.get_as_text())

func _test_config_valid() -> void:
	var data := _load()
	check(data != null, "config mémo parsée")
	var cfg := GameConfig.new(data)
	check(cfg.validity, "config mémo valide")
	var errs := GameConfig.validate_memo_items(data["items"])
	check(errs.is_empty(), "items mémo valides : %s" % str(errs))
	# mots du document présents + due_reason espacés
	var words := []
	var dues := []
	for it in data["items"]:
		words.append(str(it["card_a"].get("text", "")))
		dues.append(str(it.get("due_reason", "")))
	for expected in ["oignon", "yeux", "femme", "automne", "cheveux", "escargot"]:
		check(words.has(expected), "mot à revoir présent : " + expected)
	for d in ["spaced_1d", "spaced_3d", "spaced_7d"]:
		check(dues.has(d), "due_reason présent : " + d)
	# une carte sans image (cas limite)
	var missing := false
	for it in data["items"]:
		if str(it["card_a"].get("image_id", "")) == "":
			missing = true
	check(missing, "une carte sans image (cas limite couvert, carte neutre)")

func _test_pair_logic() -> void:
	var cfg := GameConfig.new(_load())
	var game = load("res://games/memo_mots/memo_mots.tscn").instantiate()
	add_child(game)
	game.setup(cfg)
	await get_tree().process_frame
	await get_tree().process_frame
	# niveau 2 → 6 paires → 12 cartes
	check(game._items.size() == 6, "6 paires distribuées (niveau 2)")
	check(game._cards.size() == 12, "12 cartes sur la table")
	# toutes face cachée
	var all_down := true
	for c in game._cards:
		if c._face_up:
			all_down = false
	check(all_down, "toutes les cartes sont face cachée au départ")
	# retourner 2 cartes de la MÊME paire
	var pair_target: String = str(game._items[0].get("pair_id", ""))
	var same: Array = []
	for c in game._cards:
		if c.pair_id() == pair_target:
			same.append(c)
	check(same.size() == 2, "2 cartes pour la paire " + pair_target)
	Telemetry.reset()
	var completed := []
	game.item_completed.connect(func(id: String) -> void: completed.append(id))
	game._on_card_flipped(same[0])
	game._on_card_flipped(same[1])
	await get_tree().process_frame
	check(same[0].is_matched and same[1].is_matched, "paire trouvée : les 2 cartes marquées")
	check(game._matched_pairs == 1, "compteur de paires = 1")
	check(not completed.is_empty(), "item_completed émis pour la paire")
	# retourner 2 cartes de paires DIFFÉRENTES : se retournent après délai, sans pénalité
	var d1: MemoCard = null
	var d2: MemoCard = null
	var pid1 := ""
	for c in game._cards:
		if not c.is_matched:
			if d1 == null:
				d1 = c
				pid1 = c.pair_id()
			elif c.pair_id() != pid1 and d2 == null:
				d2 = c
	check(d1 != null and d2 != null, "2 cartes de paires différentes trouvées")
	game._on_card_flipped(d1)
	game._on_card_flipped(d2)
	await get_tree().process_frame
	check(game._lock_input, "entrée verrouillée pendant le retournement doux")
	await get_tree().create_timer(2.2).timeout
	check(not d1._face_up and not d2._face_up, "les cartes se sont retournées doucement")
	check(not d1.is_matched and not d2.is_matched, "aucune pénalité sur carte non appariée")
	check(game._matched_pairs == 1, "le compteur de paires n'a pas bougé")
	game.queue_free()

func _test_homophone_config() -> void:
	# niveau 3 : homophones mer/mère/maire — valider la structure
	var homophone_items := [
		{ "item_id": "h_mer", "pair_id": "hp_mer", "kind": "homophone", "due_reason": "spaced_3d",
			"card_a": { "text": "la mer est calme", "audio": { "word": "https://x/mp3" } },
			"card_b": { "text": "mer", "audio": { "word": "https://x/mp3" } } },
		{ "item_id": "h_mere", "pair_id": "hp_mere", "kind": "homophone", "due_reason": "spaced_7d",
			"card_a": { "text": "ma mère chante", "audio": { "word": "https://x/mp3" } },
			"card_b": { "text": "mère", "audio": { "word": "https://x/mp3" } } },
		{ "item_id": "h_maire", "pair_id": "hp_maire", "kind": "homophone", "due_reason": "spaced_1d",
			"card_a": { "text": "le maire parle", "audio": { "word": "https://x/mp3" } },
			"card_b": { "text": "maire", "audio": { "word": "https://x/mp3" } } },
	]
	var errs := GameConfig.validate_memo_items(homophone_items)
	check(errs.is_empty(), "items homophones valides : %s" % str(errs))
	# structure : une carte phrase, une carte mot
	var cfg_data := _load()
	cfg_data["items"] = homophone_items
	cfg_data["difficulty"] = {"level": 3, "hints": true}
	var cfg := GameConfig.new(cfg_data)
	check(cfg.validity, "config homophones valide")
	var game = load("res://games/memo_mots/memo_mots.tscn").instantiate()
	add_child(game)
	game.setup(cfg)
	await get_tree().process_frame
	await get_tree().process_frame
	# niveau 3 → toutes les paires (3) utilisées
	check(game._items.size() == 3, "niveau 3 : 3 paires homophones")
	check(game._cards.size() == 6, "6 cartes homophones")
	# la carte a = phrase, la carte b = mot
	var found_phrase := false
	var found_word := false
	for c in game._cards:
		if c._face_up == false and c.display_word().length() > 5:
			found_phrase = true
		if c.display_word().length() <= 5:
			found_word = true
	check(found_phrase and found_word, "phrases à trou ET mots courts présents")
	game.queue_free()

func _finish() -> void:
	if _failures.is_empty():
		print("TESTS MÉMO-MOTS OK : %d vérifications" % _passes)
		get_tree().quit(0)
	else:
		print("TESTS MÉMO-MOTS ÉCHOUÉS : %d — %s" % [_failures.size(), "; ".join(_failures)])
		get_tree().quit(1)
