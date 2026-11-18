## Fumée Syllabo : flux main → config → session → 1er mot (bus) au tambour.
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
	var f := FileAccess.open("res://dev/config_syllabo.json", FileAccess.READ)
	Bridge.emit_config_now(JSON.parse_string(f.get_as_text()))
	await get_tree().create_timer(3.0).timeout
	var names := []
	for ev in Telemetry.log_snapshot():
		names.append(str(ev.get("name")))
	check(names.has("session_started"), "session_started émis")
	check(names.has("item_presented"), "item_presented émis (bus)")
	var main_node := get_tree().root.get_node_or_null("Main")
	if main_node != null and main_node._current_game != null:
		var game = main_node._current_game
		check(str(game.get_script().resource_path).contains("syllabo"), "jeu Syllabo chargé")
		check(str(game._current.get("word")) == "bus", "1er mot = bus")
		check(game._drum != null, "tambour affiché")
	_finish()

func check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
	else:
		_failures.append(label)
		push_error("FAIL : " + label)

func _finish() -> void:
	if _failures.is_empty():
		print("FUMÉE SYLLABO OK : %d vérifications" % _passes)
		get_tree().quit(0)
	else:
		print("FUMÉE SYLLABO ÉCHOUÉE : %d — %s" % [_failures.size(), "; ".join(_failures)])
		get_tree().quit(1)
