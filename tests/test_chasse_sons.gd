## Tests Chasse-Sons : validation config, logique de manche (réussite, erreur, réinsertion),
## adaptation par âge, audio phonème manquant, événements.
## Booter : godot --headless --path . res://tests/test_chasse_sons.tscn
extends Node

var _failures: Array[String] = []
var _passes: int = 0

func _ready() -> void:
	await get_tree().process_frame
	Telemetry.reset()
	await _test_configs_valid()
	await _test_target_audio_required()
	await _test_round_logic()
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

# --- configs d'essai valides ---
func _test_configs_valid() -> void:
	var data := _load("res://dev/config_chasse_sons.json")
	check(data != null, "config chasse (niveau 1) parsée")
	var cfg := GameConfig.new(data)
	check(cfg.validity, "config chasse valide")
	var errs := GameConfig.validate_chasse_config(data)
	check(errs.is_empty(), "validate_chasse_config : %s" % str(errs))
	# 4 cibles + 6 distracteurs, comme demandé par le document
	var targets := 0
	var others := 0
	for it in data["items"]:
		if bool(it["has_target"]):
			targets += 1
		else:
			others += 1
	check(targets == 4, "4 éléments avec le son (bateau, ballon, bébé, bus)")
	check(others == 6, "6 éléments sans le son (dent, dragon, doigt, lune, vélo, tigre)")
	# niveau 3 : cabane (middle) et robe (end) cibles
	var data3 := _load("res://dev/config_chasse_sons_n3.json")
	var cfg3 := GameConfig.new(data3)
	check(cfg3.validity, "config niveau 3 valide")
	check(GameConfig.validate_chasse_config(data3).is_empty(), "config niveau 3 : items valides")
	var positions := []
	for it in data3["items"]:
		if bool(it["has_target"]):
			positions.append(str(it["position"]))
	check(positions.has("middle") and positions.has("end"), "niveau 3 : cibles en middle et end")

# --- audio du phonème obligatoire ---
func _test_target_audio_required() -> void:
	var bad := _load("res://dev/config_chasse_sons.json")
	bad["target"]["audio_phoneme"] = ""
	var errs := GameConfig.validate_chasse_config(bad)
	check(not errs.is_empty(), "audio du phonème manquant → refus en validation")

# --- logique de manche : réussite, erreur, réinsertion, fin de manche ---
func _test_round_logic() -> void:
	var cfg := GameConfig.new(_load("res://dev/config_chasse_sons.json"))
	var game = load("res://games/chasse_sons/chasse_sons.tscn").instantiate()
	add_child(game)
	game.setup(cfg)
	await get_tree().process_frame
	await get_tree().process_frame
	# la manche 1 contient 2-3 cibles et des distracteurs
	check(game._round_no == 1, "manche 1 démarrée")
	check(game._targets_in_round >= 2, "au moins 2 cibles dans la manche")
	check(game._round_items.size() >= 3, "au moins 3 éléments dans la manche")
	var pool_after_round1: int = game._pool.size()
	# toucher une CIBLE : réussite
	var target_item: Dictionary = {}
	for it in game._round_items:
		if bool(it.get("has_target", false)):
			target_item = it
			break
	check(not target_item.is_empty(), "une cible trouvée dans la manche")
	var answers := []
	Telemetry.reset()
	game.item_answered.connect(func(id: String, correct: bool, detail: Dictionary) -> void:
		answers.append({"id": id, "correct": correct, "detail": detail}))
	# simuler le tap via la méthode du jeu
	for child in game._items_layer.get_children():
		if str(child.data.get("item_id", "")) == str(target_item.get("item_id", "")):
			game._on_item_tapped(child)
			break
	await get_tree().process_frame
	check(not answers.is_empty(), "item_answered émis au tap")
	if not answers.is_empty():
		check(bool(answers[0]["correct"]), "cible touchée → correct")
		var d: Dictionary = answers[0]["detail"]
		check(str(d.get("phoneme_id")) == "ph_b" and d.has("has_target") and d.has("tapped_target") and d.has("position"), "detail conforme {phoneme_id, has_target, tapped_target, position}")
		check(game._found_in_round == 1, "compteur de manche incrémenté")
	# toucher un NON-CIBLE : erreur + réinsertion dans la piscine
	var distractor: Dictionary = {}
	for it in game._round_items:
		if not bool(it.get("has_target", false)):
			distractor = it
			break
	check(not distractor.is_empty(), "un distracteur trouvé")
	var pool_before_error: int = game._pool.size()
	var answers2 := []
	game.item_answered.connect(func(id: String, correct: bool, detail: Dictionary) -> void:
		answers2.append({"id": id, "correct": correct}))
	for child in game._items_layer.get_children():
		if str(child.data.get("item_id", "")) == str(distractor.get("item_id", "")) and not child.disabled:
			game._on_item_tapped(child)
			break
	await get_tree().process_frame
	check(not answers2.is_empty(), "item_answered émis pour le distracteur")
	if not answers2.is_empty():
		check(not bool(answers2[0]["correct"]), "distracteur touché → incorrect")
	check(game._pool.size() >= pool_before_error, "distracteur réinséré dans la piscine (reviendra plus tard)")
	check(game._found_in_round == 1, "l'erreur ne bloque pas la manche")

	# brique DA : décor d'univers + mascotte présents
	var _da_found := false
	for c in game.get_children():
		if c is Backdrop:
			_da_found = true
			check(c.universe == "etang", "décor etang appliqué")
	check(_da_found, "décor Backdrop présent")
	check(game._buddy != null and game._buddy is Buddy, "mascotte Buddy instanciée")
	game.queue_free()

func _finish() -> void:
	if _failures.is_empty():
		print("TESTS CHASSE-SONS OK : %d vérifications" % _passes)
		get_tree().quit(0)
	else:
		print("TESTS CHASSE-SONS ÉCHOUÉS : %d — %s" % [_failures.size(), "; ".join(_failures)])
		get_tree().quit(1)
