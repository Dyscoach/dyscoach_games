## Tests du validateur DEF (contrat dpp/protocol.json §def, v1.2.0) :
## projection publique (answer_key absente), mots interdits, prénoms,
## bornes difficulty, template inconnu, tolérance aux champs inconnus.
## Booter avec la scène : godot --headless --path . res://tests/test_def_validator.tscn
extends Node

var _failures: Array[String] = []
var _passes: int = 0

func _ready() -> void:
	await get_tree().process_frame
	_test_valid_public_projection()
	_test_answer_key_leak_rejected()
	_test_nested_answer_leak_rejected()
	_test_forbidden_words_rejected()
	_test_first_name_rejected()
	_test_difficulty_bounds()
	_test_unknown_template_rejected()
	_test_unknown_fields_tolerated()
	_test_wrong_schema_version()
	_finish()

func check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
	else:
		_failures.append(label)
		push_error("FAIL : " + label)

## Projection publique type : config DPP memo_mots SANS corrigé.
func _public_config(extra: Dictionary = {}) -> Dictionary:
	var cfg := {
		"schema_version": 1,
		"session_id": "s_test",
		"game_id": "memo_mots",
		"locale": "fr-FR",
		"age_band": "6-8",
		"items": [
			{"item_id": "m_chat", "pair_id": "p_chat", "kind": "word_image",
			 "card_a": {"text": "chat", "audio": {}}, "card_b": {"text": "chat", "audio": {}}},
		],
	}
	for k in extra.keys():
		cfg[k] = extra[k]
	return cfg

func _test_valid_public_projection() -> void:
	var v := DefValidator.new(_public_config())
	check(v.validity, "projection publique valide")
	check(v.errors.is_empty(), "aucune erreur sur projection valide")

func _test_answer_key_leak_rejected() -> void:
	var v := DefValidator.new(_public_config({"answer_key": {"m_chat": "chat"}}))
	check(not v.validity, "answer_key racine rejeté")
	var v2 := DefValidator.new(_public_config({"correct_answer": "chat"}))
	check(not v2.validity, "correct_answer racine rejeté")

func _test_nested_answer_leak_rejected() -> void:
	var cfg := _public_config()
	cfg["items"][0]["expected_word"] = "chat"
	var v := DefValidator.new(cfg)
	check(not v.validity, "fuite de corrigé imbriquée dans items[] rejetée")
	check("; ".join(v.errors).contains("expected_word"), "message nomme le champ fautif")

func _test_forbidden_words_rejected() -> void:
	var v := DefValidator.new(_public_config({"instruction": {"text": "Trouve le mot perdu dans la grille"}}))
	check(not v.validity, "mot interdit « perdu » dans la consigne rejeté")

func _test_first_name_rejected() -> void:
	var v := DefValidator.new(_public_config({"instruction": {"text": "Aide Emma à retrouver les paires"}}))
	check(not v.validity, "prénom dans la consigne rejeté (données personnelles)")

func _test_difficulty_bounds() -> void:
	var v := DefValidator.new(_public_config({"metadata": {"subject": "francais", "difficulty": 3}}))
	check(v.validity, "difficulty 3 valide")
	var v2 := DefValidator.new(_public_config({"metadata": {"subject": "francais", "difficulty": 9}}))
	check(not v2.validity, "difficulty 9 rejetée")
	var v3 := DefValidator.new(_public_config({"metadata": {"subject": "astronomie"}}))
	check(not v3.validity, "subject inconnu rejeté")

func _test_unknown_template_rejected() -> void:
	var v := DefValidator.new(_public_config({"game_id": "quiz_math"}))
	check(not v.validity, "template_id/game_id inconnu rejeté")

func _test_unknown_fields_tolerated() -> void:
	var v := DefValidator.new(_public_config({"champ_inconnu": {"x": 1}, "un_autre": "ok"}))
	check(v.validity, "champs inconnus ignorés (tolerant_reader)")

func _test_wrong_schema_version() -> void:
	var cfg := _public_config()
	cfg["schema_version"] = 2
	var v := DefValidator.new(cfg)
	check(not v.validity, "schema_version != 1 rejeté")

func _finish() -> void:
	if _failures.is_empty():
		print("TEST DEF VALIDATOR OK : %d vérifications" % _passes)
		get_tree().quit(0)
	else:
		print("TEST DEF VALIDATOR ÉCHOUÉ : %d — %s" % [_failures.size(), "; ".join(_failures)])
		get_tree().quit(1)
