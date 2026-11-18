## Fumée Forge-Mots : le jeu se charge, reçoit la config de dev, présente le 1er mot
## et émet les événements attendus — en passant par le vrai flux main.tscn.
extends Node

var _failures: Array[String] = []
var _passes: int = 0

func _ready() -> void:
	await get_tree().process_frame
	Telemetry.reset()
	var main_scene: Node = load("res://main/main.tscn").instantiate()
	get_tree().root.add_child(main_scene)
	await get_tree().process_frame
	await get_tree().process_frame
	var payload := _load_dev_config()
	Bridge.emit_config_now(payload)
	# laisser le jeu avancer (next_word via timers) jusqu'à ~6 s
	await get_tree().create_timer(6.0).timeout
	var names := []
	for ev in Telemetry.log_snapshot():
		names.append(str(ev.get("name")))
	check(names.has("session_started"), "session_started émis")
	check(names.has("item_presented"), "item_presented émis (1er mot présenté)")
	var main_node := get_tree().root.get_node_or_null("Main")
	check(main_node != null, "scène Main chargée")
	if main_node != null:
		check(main_node._current_game != null, "jeu courant défini")
		if main_node._current_game != null:
			var game = main_node._current_game
			check(str(game.get_script().resource_path).contains("forge_mots"), "le jeu Forge-Mots est chargé (reçu : %s)" % str(game.get_script().resource_path))
			if str(game.get_script().resource_path).contains("forge_mots"):
				check(game._slots.size() >= 2, "le 1er mot a des cases (vélo = 4 tuiles)")
				check(game._reserve_tiles.size() == game._slots.size(), "réserve = cases + leurres (0 leurre niveau 1)")
	var audio_errors := []
	for ev in Telemetry.log_snapshot():
		if str(ev.get("name")) == "audio_missing":
			audio_errors.append(ev)
	# les URLs de dev sont fictives : audio_missing est le comportement attendu (le jeu continue)
	print("audio_missing : %d (comportement attendu avec URLs fictives)" % audio_errors.size())
	_finish()

func _load_dev_config() -> Dictionary:
	var file := FileAccess.open("res://dev/config_forge_mots.json", FileAccess.READ)
	return JSON.parse_string(file.get_as_text())

func check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
	else:
		_failures.append(label)
		push_error("FAIL : " + label)

func _finish() -> void:
	if _failures.is_empty():
		print("FUMÉE FORGE-MOTS OK : %d vérifications" % _passes)
		get_tree().quit(0)
	else:
		print("FUMÉE FORGE-MOTS ÉCHOUÉE : %d — %s" % [_failures.size(), "; ".join(_failures)])
		get_tree().quit(1)
