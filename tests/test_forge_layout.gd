## Vérification du layout Forge-Mots : toutes les zones interactives dans les bornes du viewport,
## cibles tactiles >= 144 px (200 px pour 6-8 ans), espacement >= 24 px, aucune tuile hors écran.
## Booter avec la scène : godot --headless --path . res://tests/test_forge_layout.tscn
extends Node

var _failures: Array[String] = []
var _passes: int = 0
var _game = null

func _ready() -> void:
	await get_tree().process_frame
	var cfg := GameConfig.new(_load_dev_config())
	var game = load("res://games/forge_mots/forge_mots.tscn").instantiate()
	add_child(game)
	game.setup(cfg)
	game.start()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	# le mot vélo est affiché : 4 cases + 4 tuiles en réserve
	_game = game
	check(_game._slot_tiles.size() == 4, "4 cases créées pour vélo")
	check(_game._reserve_tiles.size() == 4, "4 tuiles en réserve (0 leurre niveau 1)")
	# toutes les cases dans l'écran (viewport réel du test ; en prod : 1080x1920 portrait)
	var screen := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	var all_in := true
	for s in _game._slot_tiles:
		var r := Rect2(s.get_global_rect().position, s.get_global_rect().size)
		if not screen.encloses(r):
			all_in = false
	check(all_in, "toutes les cases dans le viewport")
	var tiles_in := true
	for t in _game._reserve_tiles:
		var r := Rect2(t.get_global_rect().position, t.get_global_rect().size)
		if not screen.encloses(r):
			tiles_in = false
	check(tiles_in, "toutes les tuiles de la réserve dans le viewport (critère du document)")
	# cible tactile >= 144 px (9-11 ans)
	var min_target := 1e9
	for t in _game._reserve_tiles:
		min_target = minf(min_target, t.size.x)
	check(min_target >= Tuning.TOUCH_TARGET_MIN, "cible tactile >= 144 px (reçu : %.0f)" % min_target)
	# espacement >= 24 px entre tuiles adjacentes
	var xs := []
	for t in _game._reserve_tiles:
		xs.append(t.get_global_rect().position.x)
	xs.sort()
	var min_gap := 1e9
	for i in range(1, xs.size()):
		min_gap = minf(min_gap, xs[i] - xs[i - 1])
	check(min_gap >= Tuning.TOUCH_SPACING_MIN, "espacement >= 24 px (reçu : %.0f)" % min_gap)
	# la réserve ne dépasse pas le bas : dernière tuile au-dessus de y=1920
	var max_y := 0.0
	for t in _game._reserve_tiles:
		max_y = maxf(max_y, t.get_global_rect().position.y + t.size.y)
	check(max_y <= screen.size.y, "réserve au-dessus du bord bas (max y=%.0f / %.0f)" % [max_y, screen.size.y])
	# mot avec leurres (bateau) : 4 tuiles + 2 leurres = 6 en réserve, 2 rangées max
	_game._current = {"item_id": "w_bateau", "item_type": "word", "word": "bateau", "graphemes": ["b", "a", "t", "eau"], "distractors": ["o", "au"], "syllables": ["ba", "teau"], "audio": {}}
	_game._build_word_tiles()
	await get_tree().process_frame
	check(_game._reserve_tiles.size() == 6, "bateau : 6 tuiles en réserve (4 + 2 leurres)")
	var tiles_in2 := true
	for t in _game._reserve_tiles:
		var r := Rect2(t.get_global_rect().position, t.get_global_rect().size)
		if not screen.encloses(r):
			tiles_in2 = false
	check(tiles_in2, "bateau : toutes les tuiles dans le viewport")
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

func _finish() -> void:
	if _game != null:
		_game.queue_free()
	if _failures.is_empty():
		print("TESTS LAYOUT FORGE OK : %d vérifications" % _passes)
		get_tree().quit(0)
	else:
		print("TESTS LAYOUT FORGE ÉCHOUÉS : %d — %s" % [_failures.size(), "; ".join(_failures)])
		get_tree().quit(1)
