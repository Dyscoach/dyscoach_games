extends Node
## Applique le thème de la configuration (palette, fond, habillage) sans changer les règles.
## Respecte reduce_motion (pas de secousse, pas de particules) et la taille de texte.
## Police OpenDyslexic partout ; fond #F8F7FF ; fort contraste ; minuscules ; pas de cursive.

signal theme_applied

const FONT_REGULAR := "res://assets/fonts/OpenDyslexic-Regular.otf"
const FONT_BOLD := "res://assets/fonts/OpenDyslexic-Bold.otf"

# Palette de base ( WCAG AA sur fond clair )
const BG := Color("F8F7FF")
const INK := Color("1a1b2e")
const INK_SOFT := Color("4a4b63")
const ACCENT := Color("3752ed")
const ACCENT_SOFT := Color("c9d3ff")
const GOOD := Color("2e7d43")
const GOOD_SOFT := Color("d7f0df")
const WARN := Color("8a5b00")
const WARN_SOFT := Color("ffedb8")
const SURFACE := Color("ffffff")
const BORDER := Color("c7c9e0")

var reduce_motion: bool = false
var music_enabled: bool = true
var show_time_digits: bool = false
var skin_id: String = "bulles"
var age_band: String = "9-11"
var text_scale: float = 1.0
var theme_id: String = "default"

var _font_regular: Font = null
var _font_bold: Font = null

func apply(config: Dictionary) -> void:
	var a11y: Dictionary = config.get("a11y", {})
	reduce_motion = bool(a11y.get("reduce_motion", false))
	music_enabled = bool(a11y.get("music", true))
	show_time_digits = bool(a11y.get("show_time_digits", false))
	age_band = str(config.get("age_band", "9-11"))
	var theme: Dictionary = config.get("theme", {})
	skin_id = str(theme.get("skin", "bulles"))
	theme_id = str(theme.get("id", "default"))
	var interaction: Dictionary = config.get("interaction", {})
	# taille cible adaptée à l'âge
	theme_applied.emit()

func font_regular() -> Font:
	if _font_regular == null:
		_font_regular = load(FONT_REGULAR)
	return _font_regular

func font_bold() -> Font:
	if _font_bold == null:
		_font_bold = load(FONT_BOLD)
	return _font_bold

func min_touch_target() -> float:
	return Tuning.TOUCH_TARGET_CHILD if age_band == "6-8" else Tuning.TOUCH_TARGET_MIN

func min_spacing() -> float:
	return Tuning.TOUCH_SPACING_MIN

## Style de bouton principal : fond accentué, texte blanc, coins arrondis, cible tactile large.
func style_primary_button(btn: Button, min_size: Vector2 = Vector2(0, 0)) -> void:
	btn.add_theme_font_override("font", font_bold())
	btn.add_theme_font_size_override("font_size", int(Tuning.FONT_SIZE_BODY * text_scale))
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.add_theme_color_override("font_focus_color", Color.WHITE)
	var sb := StyleBoxFlat.new()
	sb.bg_color = ACCENT
	sb.set_corner_radius_all(int(Tuning.UI_CORNER_RADIUS_SMALL))
	sb.content_margin_left = 40.0
	sb.content_margin_right = 40.0
	sb.content_margin_top = 24.0
	sb.content_margin_bottom = 24.0
	btn.add_theme_stylebox_override("normal", sb)
	var sb_pressed := sb.duplicate()
	sb_pressed.bg_color = ACCENT.darkened(0.15)
	btn.add_theme_stylebox_override("pressed", sb_pressed)
	var sb_hover := sb.duplicate()
	sb_hover.bg_color = ACCENT.lightened(0.08)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.custom_minimum_size = min_size

## Style de panneau/carton : fond surface, bordure douce, coins arrondis.
func style_panel(panel: PanelContainer) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = SURFACE
	sb.border_color = BORDER
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(int(Tuning.UI_CORNER_RADIUS))
	sb.content_margin_left = 32.0
	sb.content_margin_right = 32.0
	sb.content_margin_top = 24.0
	sb.content_margin_bottom = 24.0
	panel.add_theme_stylebox_override("panel", sb)

func style_label(label: Label, size: int = Tuning.FONT_SIZE_BODY, color: Color = INK, bold: bool = false) -> void:
	label.add_theme_font_override("font", font_bold() if bold else font_regular())
	label.add_theme_font_size_override("font_size", int(size * text_scale))
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

## Gerbe d'étincelles (réussite) — supprimée si reduce_motion.
func sparkle_burst(parent: Node, at: Vector2, color: Color = ACCENT) -> void:
	if reduce_motion:
		return
	for i in Tuning.FX_SPARKLE_COUNT:
		var spark := ColorRect.new()
		var size := randf_range(8.0, 18.0)
		spark.size = Vector2(size, size)
		spark.color = color
		spark.position = at
		parent.add_child(spark)
		var angle := TAU * randf()
		var dist := randf_range(60.0, 170.0)
		var dur := randf_range(0.45, 0.8)
		var tw := spark.create_tween().set_parallel(true)
		tw.tween_property(spark, "position", at + Vector2(cos(angle), sin(angle)) * dist, dur) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(spark, "modulate:a", 0.0, dur).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(spark.queue_free)

## Tremblement doux (erreur) — supprimé si reduce_motion.
func gentle_shake(node: Control) -> void:
	if reduce_motion:
		return
	var origin := node.position
	var tw := node.create_tween()
	for i in 3:
		tw.tween_property(node, "position:x", origin.x + Tuning.FX_SHAKE_AMPLITUDE, 0.06)
		tw.tween_property(node, "position:x", origin.x - Tuning.FX_SHAKE_AMPLITUDE, 0.06)
	tw.tween_property(node, "position:x", origin.x, 0.06)

## Pulsation de réussite — supprimée si reduce_motion.
func success_pulse(node: Control) -> void:
	if reduce_motion:
		return
	var pivot := node.get_viewport_rect().size * 0.5
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector2.ONE * Tuning.FX_SUCCESS_PULSE_SCALE, 0.15) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(node, "scale", Vector2.ONE, 0.15) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
