extends CanvasLayer
## Panneau de debug : touche D ou triple toucher en haut à gauche.
## Liste les événements envoyés, permet de simuler pause/resume/stop,
## de changer age_band et difficulty.level.

var _panel: Control = null
var _log_label: Label = null
var _tap_times: Array = []
var _enabled: bool = OS.is_debug_build()

func _input(event: InputEvent) -> void:
	if not _enabled:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_D:
		_toggle()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if event.position.y < 80 and event.position.x < 200:
			var now := Time.get_ticks_msec()
			_tap_times.append(now)
			_tap_times = _tap_times.filter(func(t: int) -> bool: return now - t < 1500)
			if _tap_times.size() >= 3:
				_tap_times.clear()
				_toggle()

func _toggle() -> void:
	if _panel != null:
		_panel.queue_free()
		_panel = null
		return
	_build()

func _build() -> void:
	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(900, 1200)
	ThemeService.style_panel(panel)
	_panel.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)
	var title := Label.new()
	title.text = "Panneau de debug"
	ThemeService.style_label(title, Tuning.FONT_SIZE_BODY, ThemeService.INK, true)
	vb.add_child(title)
	_log_label = Label.new()
	ThemeService.style_label(_log_label, 26, ThemeService.INK_SOFT)
	_log_label.custom_minimum_size = Vector2(840, 400)
	_log_label.clip_contents = true
	vb.add_child(_log_label)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	vb.add_child(hb)
	hb.add_child(UIKit.big_button("Pause", func() -> void: Bridge.pause_requested.emit()))
	hb.add_child(UIKit.big_button("Reprise", func() -> void: Bridge.resume_requested.emit()))
	hb.add_child(UIKit.big_button("Stop", func() -> void: Bridge.stop_requested.emit()))
	var close := UIKit.big_button("Fermer", _toggle)
	vb.add_child(close)
	_refresh_log()

func _refresh_log() -> void:
	if _log_label == null:
		return
	var snap := Telemetry.log_snapshot()
	var lines: Array[String] = []
	for ev in snap.slice(maxi(snap.size() - 12, 0)):
		lines.append("seq=%s %s %s" % [str(ev.get("seq")), str(ev.get("name")), JSON.stringify(ev.get("data", {}))])
	_log_label.text = "\n".join(lines)

func _process(_delta: float) -> void:
	if _panel != null and _log_label != null:
		_refresh_log()
