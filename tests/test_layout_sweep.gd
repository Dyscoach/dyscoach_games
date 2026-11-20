## Balayage de layout multi-ratios : chaque jeu instancié à 4 tailles réelles
## (portrait téléphone, paysage, tablette portrait, desktop large) — échec si un contrôle
## visible sort de l'écran. Les enfants de ScrollContainer sont conçus pour déborder : ignorés.
## Booter : godot --headless --path . res://tests/test_layout_sweep.tscn
extends Node

const SIZES: Array[Vector2i] = [
	Vector2i(1080, 1920),   # portrait téléphone (base)
	Vector2i(1920, 1080),   # paysage (rotation tabletne/desktop)
	Vector2i(820, 1180),    # tablette portrait
	Vector2i(2360, 1640),   # tablette paysage large
]

const GAMES := {
	"forge_mots": "res://games/forge_mots/forge_mots.tscn",
	"chasse_sons": "res://games/chasse_sons/chasse_sons.tscn",
	"duo_mots": "res://games/duo_mots/duo_mots.tscn",
	"memo_mots": "res://games/memo_mots/memo_mots.tscn",
	"syllabo": "res://games/syllabo/syllabo.tscn",
	"radar_lettres": "res://games/radar_lettres/radar_lettres.tscn",
}

var _failures: Array[String] = []
var _passes: int = 0

func _ready() -> void:
	await get_tree().process_frame
	for game_id in GAMES:
		await _sweep_game(game_id, GAMES[game_id])
	_finish()

func check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
	else:
		_failures.append(label)
		push_error("FAIL : " + label)

func _load_cfg(game_id: String) -> GameConfig:
	var path := "res://dev/config_%s.json" % game_id
	var f := FileAccess.open(path, FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	return GameConfig.new(data)

func _sweep_game(game_id: String, scene_path: String) -> void:
	for size in SIZES:
		var vp := SubViewport.new()
		vp.size = size
		get_tree().root.add_child(vp)
		var game: Node = load(scene_path).instantiate()
		vp.add_child(game)
		game.setup(_load_cfg(game_id))
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		var screen := Rect2(Vector2.ZERO, Vector2(size))
		var overflow: Array[String] = []
		_collect_overflow(game, screen, overflow)
		check(overflow.is_empty(), "%s @%s : tout dans l'écran%s" % [game_id, size, "" if overflow.is_empty() else " — " + "; ".join(overflow.slice(0, 3))])
		vp.queue_free()
		await get_tree().process_frame

func _collect_overflow(node: Node, screen: Rect2, out: Array[String]) -> void:
	for c in node.get_children():
		if c is ScrollContainer:
			continue  # le contenu scrollable déborde par conception
		if c is Control and c.is_visible_in_tree():
			var r: Rect2 = c.get_global_rect()
			if not screen.encloses(r):
				out.append("%s(%s) rect=%s" % [c.name, c.get_class(), _fmt(r)])
		_collect_overflow(c, screen, out)

func _fmt(r: Rect2) -> String:
	return "[%.0f,%.0f %.0fx%.0f]" % [r.position.x, r.position.y, r.size.x, r.size.y]

func _finish() -> void:
	if _failures.is_empty():
		print("TESTS LAYOUT-SWEEP OK : %d vérifications" % _passes)
		get_tree().quit(0)
	else:
		print("TESTS LAYOUT-SWEEP ÉCHOUÉS : %d — %s" % [_failures.size(), "; ".join(_failures)])
		get_tree().quit(1)
