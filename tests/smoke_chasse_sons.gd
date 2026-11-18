## Fumée Chasse-Sons : flux main → config → session_started → manche 1 avec éléments.
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
	Bridge.emit_config_now(_load_dev_config())
	await get_tree().create_timer(3.0).timeout
	var names := []
	for ev in Telemetry.log_snapshot():
		names.append(str(ev.get("name")))
	check(names.has("session_started"), "session_started émis")
	var main_node := get_tree().root.get_node_or_null("Main")
	# la consigne vocale est émise (play_audio du phonème) ; item_presented arrive au tap d'un élément
	check(game_instruction_sent(main_node), "consigne vocale du phonème demandée à la hôte")
	if main_node != null and main_node._current_game != null:
		var game = main_node._current_game
		check(str(game.get_script().resource_path).contains("chasse_sons"), "jeu Chasse-Sons chargé")
		check(game._round_no == 1, "manche 1 en cours")
		check(game._round_items.size() >= 3, "éléments affichés dans la manche")
	_finish()

func _load_dev_config() -> Dictionary:
	var f := FileAccess.open("res://dev/config_chasse_sons.json", FileAccess.READ)
	return JSON.parse_string(f.get_as_text())

func check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
	else:
		_failures.append(label)
		push_error("FAIL : " + label)

func _finish() -> void:
	if _failures.is_empty():
		print("FUMÉE CHASSE-SONS OK : %d vérifications" % _passes)
		get_tree().quit(0)
	else:
		print("FUMÉE CHASSE-SONS ÉCHOUÉE : %d — %s" % [_failures.size(), "; ".join(_failures)])
		get_tree().quit(1)


func game_instruction_sent(main_node: Node) -> bool:
	if main_node == null or main_node._current_game == null:
		return false
	return main_node._current_game._target.get("audio_phoneme", "") != ""
