## Preuve de rendu du StatusBanner dans le VRAI memo_mots : charge la scène,
## déclenche _set_status, capture la géométrie (largeur vs pastilles) et le
## stylebox. S'exécute headless = rendu réel.
## Booter : godot --headless --path . res://tests/test_banner_render.tscn
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
	var f := FileAccess.open("res://dev/config_memo_mots.json", FileAccess.READ)
	Bridge.emit_config_now(JSON.parse_string(f.get_as_text()))
	await get_tree().create_timer(2.5).timeout
	var main_node := get_tree().root.get_node_or_null("Main")
	var game = main_node._current_game if main_node != null else null
	check(game != null and str(game.get_script().resource_path).contains("memo_mots"), "jeu memo_mots chargé")
	if game == null:
		_finish()
		return
	var banner: StatusBanner = game._status
	check(banner != null, "StatusBanner présent dans memo_mots")
	if banner == null:
		_finish()
		return
	# Pastilles vs bandeau : le bandeau doit être LARGEMENT plus large.
	var dots: Control = game._dots
	check(dots != null, "pastilles présentes")
	banner.show_message("Bien joué, le mot chat est retrouvé !", "★", StatusBanner.Tone.SUCCESS)
	await get_tree().process_frame
	await get_tree().process_frame
	check(banner.visible, "bandeau visible après message")
	check(banner.size.x >= 560.0, "bandeau large (%.0f px ≥ 560)" % banner.size.x)
	if dots != null:
		check(banner.size.x > dots.size.x * 1.5, "bandeau ≥ 1,5× la largeur des pastilles (%.0f vs %.0f)" % [banner.size.x, dots.size.x])
	check(banner.message_text().contains("chat"), "message posé")
	var sb: StyleBoxFlat = banner.get_theme_stylebox("panel")
	check(sb != null and sb.bg_color == ThemeService.GOOD_SOFT, "teinte SUCCESS appliquée")
	_finish()

func check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
	else:
		_failures.append(label)
		push_error("FAIL : " + label)

func _finish() -> void:
	if _failures.is_empty():
		print("TEST BANNER-RENDER OK : %d vérifications" % _passes)
		get_tree().quit(0)
	else:
		print("TEST BANNER-RENDER ÉCHOUÉ : %d — %s" % [_failures.size(), "; ".join(_failures)])
		get_tree().quit(1)
