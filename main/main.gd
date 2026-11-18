extends Node
## Racine de l'application : charge un jeu selon game_id de la configuration,
## ou le bac à sable par défaut. Gère le chargement en mode développement.

const GAMES := {
	"sandbox": "res://games/sandbox/sandbox.tscn",
	"forge_mots": "res://games/forge_mots/forge_mots.tscn",
	"chasse_sons": "res://games/chasse_sons/chasse_sons.tscn",
	"duo_mots": "res://games/duo_mots/duo_mots.tscn",
	"memo_mots": "res://games/memo_mots/memo_mots.tscn",
	"syllabo": "res://games/syllabo/syllabo.tscn",
	"radar_lettres": "res://games/radar_lettres/radar_lettres.tscn",
	"sonimaux": "res://games/sonimaux/sonimaux.tscn",
}

const FALLBACK_SCENE := "res://games/sandbox/sandbox.tscn"

var _current_game: MiniGame = null
var _rest_screen: Control = null

func _ready() -> void:
	Bridge.send_ready()
	Bridge.config_received.connect(_on_config)
	Bridge.stop_requested.connect(_on_stop)
	# mode dev : aucune configuration en 2 s → config locale selon un jeu de dev ou sandbox
	Bridge.wait_for_config_or_dev("res://dev/config_sandbox.json")
	_load_scene(FALLBACK_SCENE)

func _on_config(payload: Dictionary) -> void:
	# recharger la scène racine serait coûteux : on change le jeu en place
	if _current_game != null:
		_current_game.queue_free()
		_current_game = null
	var cfg := GameConfig.new()
	cfg.parse(payload)
	if not cfg.validity:
		_load_scene(FALLBACK_SCENE)
		# afficher l'erreur par-dessus la sandbox
		await get_tree().process_frame
		var err := ErrorScreen.build("; ".join(cfg.errors))
		_current_game.add_child(err)
		Bridge.send_error("config_invalid", "; ".join(cfg.errors))
		return
	var item_errors := cfg.validate_items(cfg.game_id)
	if not item_errors.is_empty():
		_load_scene(FALLBACK_SCENE)
		Bridge.send_error("config_invalid", "; ".join(item_errors))
		return
	var path: String = GAMES.get(cfg.game_id, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		Bridge.send_error("game_unknown", "Jeu inconnu : %s" % cfg.game_id)
		return
	var packed: PackedScene = load(path)
	var game := packed.instantiate()
	add_child(game)
	if game is MiniGame:
		_current_game = game
		game.setup(cfg)
		game.start()
		game.game_completed.connect(_on_game_completed)
	else:
		Bridge.send_error("game_scene_invalid", "La scène %s n'hérite pas de MiniGame" % path)

func _on_stop() -> void:
	if _current_game != null:
		_current_game.on_time_soft_end()
		_current_game.finish_session("stopped")

func _on_game_completed(summary: Dictionary) -> void:
	if _rest_screen != null:
		return
	_rest_screen = RestScreen.build({"game_id": summary.get("game_id", "")})
	add_child(_rest_screen)
	_rest_screen.finished.connect(func() -> void:
		_rest_screen = null
	)

func _load_scene(path: String) -> void:
	if _current_game != null:
		_current_game.queue_free()
		_current_game = null
	var packed: PackedScene = load(path)
	var node := packed.instantiate()
	add_child(node)
	if node is MiniGame:
		_current_game = node
