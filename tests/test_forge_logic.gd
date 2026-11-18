## Tests logiques Forge-Mots : placement, validation per_item/at_end, aides, réinsertion.
## Le test suit le mot courant du jeu (synchronisation sur l'état réel, pas supposé).
## Booter avec la scène : godot --headless --path . res://tests/test_forge_logic.tscn
extends Node

var _failures: Array[String] = []
var _passes: int = 0
var _game = null
var _answered: Array = []
var _completed: Array = []

func _ready() -> void:
	await get_tree().process_frame
	Telemetry.reset()
	var cfg := GameConfig.new(_load_dev_config())
	_game = load("res://games/forge_mots/forge_mots.tscn").instantiate()
	add_child(_game)
	_game.setup(cfg)
	_game.start()
	_game.item_answered.connect(func(id: String, correct: bool, detail: Dictionary) -> void:
		_answered.append({"id": id, "correct": correct, "detail": detail}))
	_game.item_completed.connect(func(id: String) -> void:
		_completed.append(id))
	await get_tree().process_frame
	await get_tree().process_frame

	await _test_per_item_correct_placement()
	await _test_wrong_tile_returns_to_reserve()
	await _test_reinsertion_after_spell_out()
	await _test_at_end_validation()
	_finish()

func _load_dev_config() -> Dictionary:
	var f := FileAccess.open("res://dev/config_forge_mots.json", FileAccess.READ)
	return JSON.parse_string(f.get_as_text())

func check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
	else:
		_failures.append(label)
		push_error("FAIL : " + label)

## Attend (max 5 s) que le mot courant du jeu soit celui attendu.
func _wait_word(item_id: String) -> bool:
	var waited := 0.0
	while str(_game._current.get("item_id", "")) != item_id and waited < 5.0:
		await get_tree().create_timer(0.2).timeout
		waited += 0.2
	return str(_game._current.get("item_id", "")) == item_id

func _wait_completed(item_id: String) -> void:
	var waited := 0.0
	while not _completed.has(item_id) and waited < 4.0:
		await get_tree().create_timer(0.2).timeout
		waited += 0.2

func _complete_current_word() -> void:
	for i in _game._slots.size():
		var expected: String = _game._slots[i]
		if _game._filled[i] != expected:
			var t = _game._find_reserve_like(expected)
			if t != null:
				_game._place_tile_into(t, i)

# --- placement correct tuile par tuile (per_item) : le mot se complète ---
func _test_per_item_correct_placement() -> void:
	check(await _wait_word("w_velo"), "1er mot = vélo (w_velo)")
	check(str(_game._current.get("word")) == "vélo", "mot courant = vélo")
	var slots_match: bool = _game._slots.size() == 4 and _game._slots[0] == "v" and _game._slots[1] == "é" and _game._slots[2] == "l" and _game._slots[3] == "o"
	check(slots_match, "cases = v é l o")
	for i in 4:
		var expected: String = _game._slots[i]
		var tile = _game._find_reserve_like(expected)
		check(tile != null, "tuile %s présente en réserve" % expected)
		if tile != null:
			_game._place_tile_into(tile, i)
			check(_game._filled[i] == expected, "case %d remplie avec %s" % [i, expected])
	check(_game._all_filled(), "toutes les cases remplies")
	await _wait_completed("w_velo")
	check(_completed.has("w_velo"), "item_completed émis pour w_velo")
	check(not _answered.is_empty(), "item_answered émis pendant le placement")
	var all_ok := true
	for a in _answered:
		if str(a["id"]) == "w_velo" and not bool(a["correct"]):
			all_ok = false
	check(all_ok, "tous les placements de vélo corrects")

# --- mauvaise tuile : retour en réserve + item_answered faux + detail conforme ---
func _test_wrong_tile_returns_to_reserve() -> void:
	check(await _wait_word("w_bus"), "2e mot = bus (w_bus)")
	var answered_before: int = _answered.size()
	var wrong: String = ""
	for t in _game._reserve_tiles:
		if t.grapheme != "b":
			wrong = t.grapheme
			break
	var count_before: int = _game._reserve_tiles.size()
	var tile = _game._find_reserve_like(wrong)
	_game._place_tile_into(tile, 0)
	await get_tree().process_frame
	check(_game._filled[0] == "", "case 0 vidée après erreur")
	check(_game._reserve_tiles.size() >= count_before, "tuile revenue en réserve")
	var wrong_answered := false
	for a in _answered.slice(answered_before):
		if str(a["id"]) == "w_bus" and not bool(a["correct"]):
			wrong_answered = true
			check(a["detail"].has("expected") and a["detail"].has("chosen") and a["detail"].has("mode"), "detail conforme (expected/chosen/mode)")
	check(wrong_answered, "item_answered (faux) émis pour w_bus")
	# la bonne tuile : la case se verrouille
	var tile_b = _game._find_reserve_like("b")
	_game._place_tile_into(tile_b, 0)
	await get_tree().process_frame
	check(_game._filled[0] == "b", "bonne tuile verrouillée sur case 0")
	_complete_current_word()
	await _wait_completed("w_bus")
	check(_completed.has("w_bus"), "item_completed émis pour w_bus")

# --- 3 erreurs → décomposition + réinsertion unique ---
func _test_reinsertion_after_spell_out() -> void:
	check(await _wait_word("w_bateau"), "3e mot = bateau (w_bateau)")
	var queue_size_before: int = _game._queue.size()
	# 2 erreurs sur la case 0 (attendu b) avec la tuile "au" : hint tile_glow à la 2e
	for i in 2:
		var t = _game._find_reserve_like("au")
		if t != null:
			_game._place_tile_into(t, 0)
		await get_tree().process_frame
	# 3e erreur → spell_out + réinsertion
	var t3 = _game._find_reserve_like("au")
	if t3 != null:
		_game._place_tile_into(t3, 0)
	await get_tree().process_frame
	check(_game._spell_out_done, "spell_out déclenché après 3 erreurs")
	check(_game._queue.size() == queue_size_before + 1, "bateau réinséré dans la file (1 fois)")
	# l'item réinséré porte la trace (_reinsertions = 1)
	var requeued: Dictionary = _game._queue[_game._queue.size() - 1]["item"]
	check(int(requeued.get("_reinsertions", 0)) == 1, "l'item réinséré porte la trace (1)")
	# d'autres erreurs ne réinsèrent pas à nouveau
	_game._maybe_show_hint(0, 3)
	check(_game._queue.size() == queue_size_before + 1, "pas de 2e réinsertion")
	# compléter le mot pour avancer
	_complete_current_word()
	await _wait_completed("w_bateau")

# --- validation at_end : vérification uniquement au bouton ---
func _test_at_end_validation() -> void:
	check(await _wait_word("w_ballon"), "mot ballon atteint")
	_game._validation_at_end = true
	var answered_before: int = _answered.size()
	_complete_current_word()
	var immediate := false
	for a in _answered.slice(answered_before):
		if str(a["id"]) == "w_ballon" and not bool(a["correct"]):
			immediate = true
	check(not immediate, "at_end : aucune vérification immédiate à la pose")
	# validation au bouton : tout est correct → item_completed
	_game._on_validate_pressed()
	await _wait_completed("w_ballon")
	check(_completed.has("w_ballon"), "at_end : item_completed émis après validation bouton")
	# la réinsertion de bateau apparaît dans la file
	var found_requeued := false
	for entry in _game._queue:
		if str(entry["item"].get("item_id", "")) == "w_bateau":
			found_requeued = true
	check(found_requeued, "bateau marqué à revoir présent dans la file")

func _finish() -> void:
	_game.queue_free()
	if _failures.is_empty():
		print("TESTS LOGIQUE FORGE OK : %d vérifications" % _passes)
		get_tree().quit(0)
	else:
		print("TESTS LOGIQUE FORGE ÉCHOUÉS : %d — %s" % [_failures.size(), "; ".join(_failures)])
		get_tree().quit(1)
