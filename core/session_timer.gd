extends Node
## Temps actif de la session : page visible ET interaction dans les 30 dernières secondes.
## Pause/resume de l'hôte stoppent et relancent le compteur.
## À soft_end_at_minutes : signal soft_end (l'élément en cours se termine, puis repos).
## À max_active_minutes : signal time_limit (plus aucun nouvel élément).

signal soft_end
signal time_limit

const _active := [false, false]  # [running, visible] — conteneur muable (autoload sans état d'instance)

var running: bool = false
var visible_page: bool = false
var _last_interaction_ms: int = 0
var _accumulated_ms: int = 0
var _mark_ms: int = 0
var _max_active_minutes: float = Tuning.MAX_ACTIVE_MINUTES_DEFAULT
var _soft_end_minutes: float = Tuning.SOFT_END_MINUTES_DEFAULT
var _soft_fired: bool = false
var _limit_fired: bool = false

func _ready() -> void:
	visible_page = true
	if OS.has_feature("web"):
		var doc = JavaScriptBridge.get_interface("document")
		if doc != null:
			var cb := JavaScriptBridge.create_callback(_on_visibility_change)
			doc.addEventListener("visibilitychange", cb)

func _on_visibility_change(args: Array) -> void:
	var doc = JavaScriptBridge.get_interface("document")
	if doc == null:
		return
	var hidden = doc.get("hidden")
	visible_page = not (hidden != null and bool(hidden))
	if not visible_page:
		pause()

func configure(max_active_minutes: float, soft_end_minutes: float) -> void:
	_max_active_minutes = clampf(max_active_minutes, 1.0, Tuning.MAX_ACTIVE_MINUTES_CEILING)
	_soft_end_minutes = minf(_soft_end_minutes, _max_active_minutes - 0.5)

func start(max_active_minutes: float, soft_end_minutes: float) -> void:
	configure(max_active_minutes, soft_end_minutes)
	_accumulated_ms = 0
	_mark_ms = Time.get_ticks_msec()
	_last_interaction_ms = _mark_ms
	_soft_fired = false
	_limit_fired = false
	running = true
	visible_page = true

func pause() -> void:
	if running and _mark_ms > 0:
		_accumulated_ms += Time.get_ticks_msec() - _mark_ms
	_mark_ms = 0
	running = false

func resume() -> void:
	if not running:
		_mark_ms = Time.get_ticks_msec()
		_last_interaction_ms = _mark_ms
		running = true

func notify_interaction() -> void:
	_last_interaction_ms = Time.get_ticks_msec()

## À appeler par les jeux à chaque action de l'enfant.
func touch() -> void:
	notify_interaction()

func active_ms() -> int:
	var total := _accumulated_ms
	if running and _mark_ms > 0:
		total += Time.get_ticks_msec() - _mark_ms
	return int(total)

func is_active() -> bool:
	if not running or not visible_page:
		return false
	return Time.get_ticks_msec() - _last_interaction_ms <= Tuning.IDLE_TIMEOUT_MS

func progress_ratio() -> float:
	var minutes := active_ms() / 60000.0
	if _max_active_minutes <= 0:
		return 0.0
	# jauge calme : rapport sur soft_end (pas de chiffres affichés par le jeu)
	return clampf(minutes / maxf(_soft_end_minutes, 0.1), 0.0, 1.0)

func show_digits() -> bool:
	return ThemeService.show_time_digits

func _process(_delta: float) -> void:
	if not running:
		return
	var minutes := active_ms() / 60000.0
	if not _soft_fired and minutes >= _soft_end_minutes:
		_soft_fired = true
		soft_end.emit()
	if not _limit_fired and minutes >= _max_active_minutes:
		_limit_fired = true
		time_limit.emit()

# --- tests : horloge simulée ---
func _inject_state(active: int, run: bool) -> void:
	_accumulated_ms = active
	running = run
	_mark_ms = 0
