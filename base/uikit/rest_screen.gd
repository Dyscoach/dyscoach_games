class_name RestScreen
extends Control
## Écran de repos : conclut la séance en douceur (soleil qui descend, aucun chiffre).

signal finished

static func build(summary: Dictionary) -> RestScreen:
	var screen := RestScreen.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = ThemeService.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(center)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 32)
	center.add_child(vb)
	# soleil couchant dessiné par RestArt
	var art := RestArt.new()
	art.custom_minimum_size = Vector2(360, 360)
	var art_wrap := CenterContainer.new()
	art_wrap.add_child(art)
	vb.add_child(art_wrap)
	var title := Label.new()
	title.text = Strings.REST_TITLE
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeService.style_label(title, Tuning.FONT_SIZE_TITLE, ThemeService.INK, true)
	vb.add_child(title)
	var body := Label.new()
	var is_sonimaux: bool = str(summary.get("game_id", "")) == "sonimaux"
	body.text = Strings.REST_BODY_SONIMAUX if is_sonimaux else Strings.REST_BODY
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeService.style_label(body, Tuning.FONT_SIZE_BODY, ThemeService.INK_SOFT)
	vb.add_child(body)
	if not ThemeService.reduce_motion:
		art.modulate.a = 0.0
		var tw := art.create_tween()
		tw.tween_property(art, "modulate:a", 1.0, 0.8).set_ease(Tween.EASE_OUT)
	var done := Button.new()
	done.text = Strings.OK
	done.name = "FinishButton"
	ThemeService.style_primary_button(done, Vector2(Tuning.TOUCH_TARGET_MIN, Tuning.TOUCH_TARGET_MIN * 0.6))
	done.pressed.connect(func() -> void: screen.finished.emit(); screen.queue_free())
	var wrap := CenterContainer.new()
	wrap.add_child(done)
	vb.add_child(wrap)
	return screen

class RestArt:
	extends Control
	## Soleil derrière une colline, doux et statique (pas d'animation continue).
	func _draw() -> void:
		var w := size.x
		var h := size.y
		# ciel
		draw_rect(Rect2(Vector2.ZERO, size), Color("dfe7ff"))
		# soleil
		var sun_c := Vector2(w * 0.5, h * 0.52)
		draw_circle(sun_c, w * 0.22, Color("ffb703"))
		draw_circle(sun_c, w * 0.17, Color("ffd166"))
		# colline
		var pts := PackedVector2Array([
			Vector2(0, h * 0.8), Vector2(w * 0.3, h * 0.66), Vector2(w * 0.62, h * 0.78),
			Vector2(w * 0.85, h * 0.7), Vector2(w, h * 0.76), Vector2(w, h), Vector2(0, h),
		])
		draw_colored_polygon(pts, Color("9db8e8"))
		draw_rect(Rect2(0, h * 0.86, w, h * 0.14), Color("7f9ede"))
