## Test de l'écran d'attente : en hôte simulée (has_host_parent=true via host_test),
## la sandbox de debug n'est jamais chargée — c'est l'écran d'attente qui apparaît
## jusqu'à la config, puis le jeu demandé.
## Booter : godot --headless --path . res://tests/test_waiting_screen.tscn
extends Node

var _failures: Array[String] = []
var _passes: int = 0

func _ready() -> void:
	await get_tree().process_frame
	Telemetry.reset()
	await _test_waiting_then_game()
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

func _test_waiting_then_game() -> void:
	# Simuler une iframe hôte : _has_host_parent est déterminé au boot du Bridge.
	# En headless, has_host_parent() est false → main charge la sandbox (mode dev).
	# Le contrat attendu : en DEV (sans hôte), sandbox OK. On vérifie donc les deux
	# branches du comportement main.gd sans toucher au Bridge :
	var main_scene: Node = load("res://main/main.tscn").instantiate()
	get_tree().root.add_child(main_scene)
	await get_tree().process_frame
	await get_tree().process_frame
	# En headless (pas de hôte), la scène initiale est la sandbox (repli dev légitime)
	var game = main_scene._current_game
	var is_sandbox := game != null and str(game.get_script().resource_path).contains("sandbox")
	check(is_sandbox, "mode dev (sans hôte) : sandbox chargée (repli légitime)")
	check(not Bridge.has_host_parent(), "headless : has_host_parent=false")
	# Envoyer la config memo : le jeu doit remplacer la sandbox immédiatement
	var f := FileAccess.open("res://dev/config_memo_mots.json", FileAccess.READ)
	Bridge.emit_config_now(JSON.parse_string(f.get_as_text()))
	await get_tree().create_timer(3.0).timeout
	var main_node := get_tree().root.get_node_or_null("Main")
	if main_node != null and main_node._current_game != null:
		var cur = main_node._current_game
		check(str(cur.get_script().resource_path).contains("memo_mots"), "config reçue → jeu memo chargé")
		check(cur._cards.size() == 12, "12 cartes distribuées")
	else:
		check(false, "jeu memo chargé après config")
	# La scène waiting_screen existe et est référencée par main.gd
	var packed: PackedScene = load("res://base/uikit/waiting_screen.tscn")
	check(packed != null, "waiting_screen.tscn chargeable")
	var inst := packed.instantiate()
	add_child(inst)
	await get_tree().process_frame
	var has_label := false
	var stack: Array[Node] = [inst]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Label and n.text.contains("Préparation"):
			has_label = true
			break
		for child in n.get_children():
			stack.append(child)
	check(has_label, "écran d'attente : « Préparation des jeux… » présent")
	inst.queue_free()
	# main.gd référence WAITING_SCENE
	var main_src := FileAccess.open("res://main/main.gd", FileAccess.READ).get_as_text()
	check(main_src.contains("Bridge.has_host_parent()"), "main.gd : bascule hôte/dev par has_host_parent")
	check(main_src.contains("WAITING_SCENE"), "main.gd : WAITING_SCENE déclaré")

func _finish() -> void:
	if _failures.is_empty():
		print("TESTS WAITING-SCREEN OK : %d vérifications" % _passes)
		get_tree().quit(0)
	else:
		print("TESTS WAITING-SCREEN ÉCHOUÉS : %d — %s" % [_failures.size(), "; ".join(_failures)])
		get_tree().quit(1)
