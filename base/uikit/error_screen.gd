class_name ErrorScreen
extends Control
## Écran d'erreur calme : jamais anxiogène, propose « Réessayer ».
## Contrat DPP v1.1.0 : retry_requested est émis au clic ; le chargeur (main.gd)
## décide de l'action (réémettre ready après config_error, nettoyer, etc.).

signal retry_requested()

static func build(message: String) -> ErrorScreen:
	var screen := ErrorScreen.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.2, 0.2, 0.3, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(center)
	var panel := PanelContainer.new()
	ThemeService.style_panel(panel)
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 24)
	vb.custom_minimum_size = Vector2(720, 0)
	panel.add_child(vb)
	var title := Label.new()
	title.text = Strings.ERROR_TITLE
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeService.style_label(title, Tuning.FONT_SIZE_TITLE, ThemeService.INK, true)
	vb.add_child(title)
	var body := Label.new()
	body.text = Strings.ERROR_BODY
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeService.style_label(body, Tuning.FONT_SIZE_BODY, ThemeService.INK_SOFT)
	vb.add_child(body)
	var btn := Button.new()
	btn.text = Strings.RETRY
	btn.name = "RetryButton"
	ThemeService.style_primary_button(btn, Vector2(Tuning.TOUCH_TARGET_MIN, Tuning.TOUCH_TARGET_MIN * 0.6))
	var wrap := CenterContainer.new()
	wrap.add_child(btn)
	vb.add_child(wrap)
	btn.pressed.connect(func() -> void:
		Bridge.send_event("error_retry", {"code": "retry_requested"})
		screen.retry_requested.emit()
		screen.queue_free()
	)
	# le message technique n'est pas montré à l'enfant ; il reste dans l'événement "error"
	return screen

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
