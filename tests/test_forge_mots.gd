## Tests Forge-Mots : placement, validation, aides, réinsertion, événements.
## Booter avec la scène : godot --headless --path . res://tests/test_forge_mots.tscn
extends Node

var _failures: Array[String] = []
var _passes: int = 0

func _ready() -> void:
	await get_tree().process_frame
	_test_dev_config_valid()
	_test_invalid_config_refused()
	_test_single_tile_refused()
	_test_events_conformity()
	_test_confusion_pair()
	_finish()

func check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
	else:
		_failures.append(label)
		push_error("FAIL : " + label)

func _load_dev_config() -> Dictionary:
	var file := FileAccess.open("res://dev/config_forge_mots.json", FileAccess.READ)
	return JSON.parse_string(file.get_as_text())

# --- la config de dev (6 mots + 1 homophone) est valide ---
func _test_dev_config_valid() -> void:
	var data := _load_dev_config()
	check(data != null, "config forge de dev parsée")
	var cfg := GameConfig.new()
	cfg.parse(data)
	check(cfg.validity, "config forge de dev valide")
	check(cfg.item_count() == 7, "7 items (6 mots + 1 homophone)")
	var errs := GameConfig.validate_forge_items(cfg.items)
	check(errs.is_empty(), "items forge valides : %s" % str(errs))
	# mots d'essai du document présents
	var words := []
	for it in cfg.items:
		words.append(str(it.get("word", "")))
	for expected in ["vélo", "bus", "bateau", "ballon", "champion", "dauphin"]:
		check(words.has(expected), "mot d'essai présent : " + expected)

# --- config invalide : mot à 1 seule tuile refusé en validation ---
func _test_single_tile_refused() -> void:
	var bad_items := [{"item_id": "x", "item_type": "word", "word": "on", "graphemes": ["on"], "distractors": [], "syllables": ["on"], "audio": {}}]
	var errs := GameConfig.validate_forge_items(bad_items)
	check(not errs.is_empty(), "mot à 1 seule tuile refusé en validation")
	# homophone sans réponse
	var bad_hp := [{"item_id": "y", "item_type": "homophone", "sentence_before": "Il", "sentence_after": "un chien", "choices": ["a", "à"], "audio": {}}]
	errs = GameConfig.validate_forge_items(bad_hp)
	check(not errs.is_empty(), "homophone sans answer refusé")

func _test_invalid_config_refused() -> void:
	var file := FileAccess.open("res://dev/config_forge_mots_invalide.json", FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	check(data != null, "config invalide parsée")
	var cfg := GameConfig.new()
	cfg.parse(data)
	check(cfg.validity, "config invalide : champs communs OK")
	var errs := GameConfig.validate_forge_items(cfg.items)
	check(not errs.is_empty(), "config invalide : items rejetés (1 tuile)")

# --- événements : conformité au schéma ---
func _test_events_conformity() -> void:
	Telemetry.reset()
	Telemetry.emit_event("session_started", {"game_id": "forge_mots", "age_band": "9-11", "level": 2})
	Telemetry.emit_event("item_presented", {"item_id": "w_bateau"})
	Telemetry.emit_event("item_answered", {"item_id": "w_bateau", "attempt_no": 1, "correct": true, "response_ms": 4200, "detail": {"expected": "eau", "chosen": "eau", "tile_pair": "", "mode": "tile"}})
	Telemetry.emit_event("item_completed", {"item_id": "w_bateau", "first_try": true, "attempts": 1, "hints": 0})
	Telemetry.emit_event("hint_shown", {"item_id": "w_bateau", "hint_type": "tile_glow"})
	Telemetry.emit_event("audio_replayed", {"item_id": "w_bateau"})
	Telemetry.emit_event("break_started", {"reason": "soft_end"})
	Telemetry.emit_event("session_ended", {"reason": "completed", "active_ms": 120000, "items_done": 6})
	var snap := Telemetry.log_snapshot()
	var seqs := []
	for ev in snap:
		seqs.append(int(ev.get("seq")))
		check(ev.has("t_ms"), "event %s porte t_ms" % str(ev.get("name")))
	var sorted := seqs.duplicate()
	sorted.sort()
	check(seqs == sorted, "séquences strictement croissantes")
	var names := []
	for ev in snap:
		names.append(str(ev.get("name")))
	for expected in ["session_started", "item_presented", "item_answered", "item_completed", "hint_shown", "audio_replayed", "break_started", "session_ended"]:
		check(names.has(expected), "événement du protocole présent : " + expected)
	# aucune donnée personnelle dans les événements
	var all_json := JSON.stringify(snap)
	check(not all_json.contains("Inès"), "aucun prénom dans les événements")

# --- paires de confusion ---
func _test_confusion_pair() -> void:
	var game: Node = load("res://games/forge_mots/forge_mots.gd").new()
	check(game._confusion_pair("an", "on") == "an/on", "paire an/on détectée")
	check(game._confusion_pair("on", "an") == "an/on", "paire symétrique on/an")
	check(game._confusion_pair("b", "d") == "b/d", "paire b/d détectée")
	check(game._confusion_pair("eau", "x") == "", "pas de paire hors liste")
	game.queue_free()

func _finish() -> void:
	if _failures.is_empty():
		print("TESTS FORGE-MOTS OK : %d vérifications" % _passes)
		get_tree().quit(0)
	else:
		print("TESTS FORGE-MOTS ÉCHOUÉS : %d — %s" % [_failures.size(), "; ".join(_failures)])
		get_tree().quit(1)
