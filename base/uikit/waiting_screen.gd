extends Control
## Écran d'attente : affiché pendant le démarrage du moteur (avant la réception
## de la configuration hôte). Remplace l'ancien repli sandbox en production —
## l'enfant ne doit JAMAIS voir l'écran de debug du socle.
## Sans interaction : une pastille qui respire doucement + « Préparation des jeux… ».
## Si la config n'arrive jamais, main.gd affiche l'écran d'erreur calme (contrat v1.1.0)
## par-dessus cet écran ; cet écran lui-même ne propose rien de cliquable.

var _breath: Control = null

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = ThemeService.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 28)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vb)
	# pastille qui respire (supprimée si reduce_motion)
	_breath = Control.new()
	_breath.custom_minimum_size = Vector2(96, 96)
	_breath.pivot_offset = Vector2(48, 48)
	_breath.draw.connect(_draw_dot)
	var wrap := CenterContainer.new()
	wrap.add_child(_breath)
	vb.add_child(wrap)
	var label := Label.new()
	label.text = "Préparation des jeux…"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeService.style_label(label, Tuning.FONT_SIZE_BODY, ThemeService.INK_SOFT)
	vb.add_child(label)
	if not ThemeService.reduce_motion:
		var tw := _breath.create_tween().set_loops()
		tw.tween_property(_breath, "scale", Vector2(1.12, 1.12), 0.9) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		tw.tween_property(_breath, "scale", Vector2.ONE, 0.9) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func _draw_dot() -> void:
	var c := _breath.size * 0.5
	_breath.draw_circle(c, 34.0, ThemeService.ACCENT_SOFT)
	_breath.draw_circle(c, 22.0, ThemeService.ACCENT)
