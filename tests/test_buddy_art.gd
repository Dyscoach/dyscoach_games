## Vérification des dessins porteurs (BuddyArt) : tambour dans le bouton Syllabo,
## écran radar dans Radar, créature compagnon dans Sonimaux.
## Booter : godot --headless --path . res://tests/test_buddy_art.tscn
extends Node

var _failures: Array[String] = []
var _passes: int = 0

func _ready() -> void:
	await get_tree().process_frame
	await _test_syllabo_drum()
	await _test_radar_screen()
	await _test_sonimaux_creature()
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

func _test_syllabo_drum() -> void:
	var cfg := GameConfig.new(_load("res://dev/config_syllabo.json"))
	var game: Node = load("res://games/syllabo/syllabo.tscn").instantiate()
	add_child(game)
	game.setup(cfg)
	await get_tree().process_frame
	await get_tree().process_frame
	check(game._drum != null, "bouton tambour présent")
	var has_art := false
	for c in game._drum.get_children():
		if c is BuddyArt:
			has_art = true
			check(c.kind == "drum", "dessin tambour (kind=drum) dans le bouton")
	check(has_art, "BuddyArt tambour enfant du bouton (l'emoji est remplacé)")
	check(game._drum.text == "", "bouton sans texte : le dessin porte le sens")
	game.queue_free()

func _test_radar_screen() -> void:
	var cfg := GameConfig.new(_load("res://dev/config_radar_lettres.json"))
	var game: Node = load("res://games/radar_lettres/radar_lettres.tscn").instantiate()
	add_child(game)
	game.setup(cfg)
	await get_tree().process_frame
	await get_tree().process_frame
	var found := false
	for c in game.get_children():
		if c is Backdrop:
			found = true
			check(c.universe == "nuit", "décor nuit toujours appliqué")
	check(found, "décor Backdrop présent")
	# l'écran radar dessiné vit dans le VBox principal, sous le modèle
	var art_found := false
	for c in game._main_vb.get_children():
		if c is HBoxContainer:
			for cc in c.get_children():
				if cc is BuddyArt and cc.kind == "radar":
					art_found = true
	check(art_found, "écran radar dessiné (kind=radar) sous le modèle")
	game.queue_free()

func _test_sonimaux_creature() -> void:
	var cfg := GameConfig.new(_load("res://dev/config_sonimaux.json"))
	var game: Node = load("res://games/sonimaux/sonimaux.tscn").instantiate()
	add_child(game)
	game.setup(cfg)
	await get_tree().process_frame
	await get_tree().process_frame
	check(game._companion_art != null and game._companion_art.kind == "creature", "compagnon Bibi dessiné (kind=creature)")
	check(game._companion_art.get_parent() != null, "compagnon attaché à l'arbre")
	# le nom du compagnon est affiché à côté du dessin
	var name_seen := false
	for c in game._companion_art.get_parent().get_children():
		if c is Label and c.text == "Bibi":
			name_seen = true
	check(name_seen, "nom du compagnon affiché à côté du dessin")
	game.queue_free()

func _finish() -> void:
	if _failures.is_empty():
		print("TESTS BUDDY-ART OK : %d vérifications" % _passes)
		get_tree().quit(0)
	else:
		print("TESTS BUDDY-ART ÉCHOUÉS : %d — %s" % [_failures.size(), "; ".join(_failures)])
		get_tree().quit(1)
