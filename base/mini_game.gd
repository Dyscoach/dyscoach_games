class_name MiniGame
extends Control
## Classe de base de tout jeu DysCoach.
## Reçoit un GameConfig validé, émet les signaux du protocole et gère le cycle de vie.
## Le jeu ne change JAMAIS la difficulté de lui-même : il applique uniquement des aides.

signal item_presented(item_id: String)
signal item_answered(item_id: String, correct: bool, detail: Dictionary)
signal item_completed(item_id: String)
signal game_completed(summary: Dictionary)

var config: GameConfig = null
var current_item_id: String = ""
var _items_done: int = 0
var _finish_requested: bool = false

func setup(cfg: GameConfig) -> void:
	config = cfg
	ThemeService.apply(cfg.raw)
	SessionTimer.start(cfg.max_active_minutes, cfg.soft_end_minutes)
	Telemetry.emit_event("session_started", {
		"game_id": cfg.game_id,
		"age_band": cfg.age_band,
		"level": cfg.difficulty_level,
	})
	_setup(cfg)
	# start() est appelé séparément par le chargeur de jeux (main) : jamais deux fois.

var _started: bool = false

# Méthodes à surcharger
func _setup(_cfg: GameConfig) -> void: pass
func start() -> void:
	if _started:
		return
	_started = true
	on_start()

## Surcharger ceci (et non start) pour démarrer le jeu.
func on_start() -> void: pass
func on_pause() -> void: pass
func on_resume() -> void: pass
func on_time_soft_end() -> void: pass
func on_time_limit() -> void: pass

# --- helpers de cycle de vie pour les jeux dérivés ---

func announce_item(item_id: String) -> void:
	current_item_id = item_id
	Telemetry.emit_event("item_presented", {"item_id": item_id})
	item_presented.emit(item_id)

func report_answer(item_id: String, correct: bool, detail: Dictionary, attempt_no: int, response_ms: int) -> void:
	Telemetry.emit_event("item_answered", {
		"item_id": item_id,
		"attempt_no": attempt_no,
		"correct": correct,
		"response_ms": response_ms,
		"detail": detail,
	})
	item_answered.emit(item_id, correct, detail)

func complete_item(item_id: String, first_try: bool, attempts: int, hints: int) -> void:
	_items_done += 1
	Telemetry.emit_event("item_completed", {
		"item_id": item_id,
		"first_try": first_try,
		"attempts": attempts,
		"hints": hints,
	})
	item_completed.emit(item_id)

func emit_break(reason: String) -> void:
	Telemetry.emit_event("break_started", {"reason": reason})

func finish_session(reason: String) -> void:
	if _finish_requested:
		return
	_finish_requested = true
	var active := SessionTimer.active_ms()
	Telemetry.emit_event("session_ended", {"reason": reason, "active_ms": active, "items_done": _items_done})
	var summary := {"reason": reason, "active_ms": active, "items_done": _items_done}
	game_completed.emit(summary)
	Bridge.send_session_end(reason, active, _items_done)

# --- branchement du cycle de vie hôte ---

func _ready() -> void:
	Bridge.pause_requested.connect(_on_bridge_pause)
	Bridge.resume_requested.connect(_on_bridge_resume)
	Bridge.stop_requested.connect(_on_bridge_stop)
	SessionTimer.soft_end.connect(_on_timer_soft_end)
	SessionTimer.time_limit.connect(_on_timer_limit)

func _on_bridge_pause() -> void:
	SessionTimer.pause()
	on_pause()

func _on_bridge_resume() -> void:
	SessionTimer.resume()
	on_resume()

func _on_bridge_stop() -> void:
	on_time_soft_end()
	finish_session("stopped")

func _on_timer_soft_end() -> void:
	Telemetry.emit_event("break_started", {"reason": "soft_end"})
	on_time_soft_end()

func _on_timer_limit() -> void:
	on_time_limit()
	finish_session("time_limit")

## Jauge calme de temps (arc de soleil/lune), sans chiffres.
func build_time_gauge() -> Control:
	var gauge := TimeGauge.new()
	gauge.custom_minimum_size = Vector2(96, 96)
	return gauge

## Écran d'erreur calme (config invalide, épisode refusé...).
func show_error_screen(code: String, message: String) -> void:
	Bridge.send_error(code, message)
	var overlay := ErrorScreen.build(message)
	add_child(overlay)
