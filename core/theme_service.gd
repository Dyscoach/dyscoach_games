extends Node
## Applique le thème de la configuration (palette, fond, habillage) sans changer les règles.
## Respecte reduce_motion (pas de secousse, pas de particules) et la taille de texte.
## Police Andika (SIL OFL, conçue pour lecteurs débutants : b/d/p/q distincts,
## accents français complets, formes épurées) ; OpenDyslexic en repli si absente.
## Fond #F8F7FF ; fort contraste ; minuscules ; pas de cursive.

signal theme_applied

const FONT_REGULAR := "res://assets/fonts/Andika-Regular.ttf"
const FONT_BOLD := "res://assets/fonts/Andika-Bold.ttf"
## Repli si Andika absente du build (suppression accidentelle).
const FONT_FALLBACK_REGULAR := "res://assets/fonts/OpenDyslexic-Regular.otf"
const FONT_FALLBACK_BOLD := "res://assets/fonts/OpenDyslexic-Bold.otf"

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
const CARD_BACK := Color("5c76f0")  # dos des cartes mémoire (accent profond, contraste AA avec le blanc)

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
	# taille de texte relative (1.0 = normal) — lue depuis la configuration, bornée
	text_scale = clampf(float(a11y.get("text_scale", 1.0)), 0.85, 1.5)
	age_band = str(config.get("age_band", "9-11"))
	var theme: Dictionary = config.get("theme", {})
	skin_id = str(theme.get("skin", "bulles"))
	theme_id = str(theme.get("id", "default"))
	var interaction: Dictionary = config.get("interaction", {})
	# taille cible adaptée à l'âge
	theme_applied.emit()

func font_regular() -> Font:
	if _font_regular == null:
		_font_regular = load(FONT_REGULAR) if ResourceLoader.exists(FONT_REGULAR) else load(FONT_FALLBACK_REGULAR)
	return _font_regular

func font_bold() -> Font:
	if _font_bold == null:
		_font_bold = load(FONT_BOLD) if ResourceLoader.exists(FONT_BOLD) else load(FONT_FALLBACK_BOLD)
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

## Gerbe d'étoiles (réussite) — supprimée si reduce_motion.
## Formes variées (étoiles, cercles, losanges) teintées : plus de carrés bruts.
func sparkle_burst(parent: Node, at: Vector2, color: Color = ACCENT) -> void:
	if reduce_motion:
		return
	for i in Tuning.FX_SPARKLE_COUNT:
		var spark := Spark.new()
		var s := randf_range(9.0, 18.0)
		spark.size = Vector2(s, s)
		spark.spark_color = _spark_variant(color, i)
		spark.kind = i % 3  # étoile / cercle / losange
		spark.position = at - Vector2(s, s) * 0.5
		parent.add_child(spark)
		var angle := TAU * randf()
		var dist := randf_range(60.0, 170.0)
		var dur := randf_range(0.45, 0.8)
		var tw := spark.create_tween().set_parallel(true)
		tw.tween_property(spark, "position", spark.position + Vector2(cos(angle), sin(angle)) * dist, dur) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(spark, "rotation", randf_range(-1.5, 1.5), dur).set_ease(Tween.EASE_OUT)
		tw.tween_property(spark, "modulate:a", 0.0, dur).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(spark.queue_free)

func _spark_variant(color: Color, i: int) -> Color:
	match i % 4:
		0: return color
		1: return color.lerp(Color.WHITE, 0.45)
		2: return color.lerp(SUN_SPARK, 0.55)
		_: return color.lerp(SUN_SPARK, 0.3).lerp(Color.WHITE, 0.2)

const SUN_SPARK := Color("ffb703")

## Étincelle dessinée : étoile 4 branches, cercle ou losange — jamais un carré brut.
class Spark:
	extends Control
	var spark_color: Color = Color.WHITE
	var kind: int = 0
	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		match kind:
			0:  # étoile 4 branches
				var pts := PackedVector2Array([
					c + Vector2(0, -r), c + Vector2(r * 0.28, -r * 0.28),
					c + Vector2(r, 0), c + Vector2(r * 0.28, r * 0.28),
					c + Vector2(0, r), c + Vector2(-r * 0.28, r * 0.28),
					c + Vector2(-r, 0), c + Vector2(-r * 0.28, -r * 0.28),
				])
				draw_colored_polygon(pts, spark_color)
			1:  # cercle
				draw_circle(c, r * 0.7, spark_color)
			_:  # losange
				var pts2 := PackedVector2Array([
					c + Vector2(0, -r), c + Vector2(r * 0.55, 0),
					c + Vector2(0, r), c + Vector2(-r * 0.55, 0),
				])
				draw_colored_polygon(pts2, spark_color)

## Tremblement doux (erreur) — supprimé si reduce_motion.
## Rotation de faible amplitude autour du centre : ne combat pas le layout des containers.
func gentle_shake(node: Control) -> void:
	if reduce_motion:
		return
	node.pivot_offset = node.size * 0.5
	var tw := node.create_tween()
	for i in 3:
		tw.tween_property(node, "rotation", deg_to_rad(Tuning.FX_SHAKE_ANGLE_DEG), 0.06)
		tw.tween_property(node, "rotation", deg_to_rad(-Tuning.FX_SHAKE_ANGLE_DEG), 0.06)
	tw.tween_property(node, "rotation", 0.0, 0.06)

## Pulsation de réussite, centrée sur le contrôle (pivot_offset au centre) —
## supprimée si reduce_motion. Reste à l'échelle 1 à la fin.
func success_pulse(node: Control) -> void:
	if reduce_motion:
		return
	node.pivot_offset = node.size * 0.5
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector2.ONE * Tuning.FX_SUCCESS_PULSE_SCALE, 0.15) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(node, "scale", Vector2.ONE, 0.15) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

## Apparition douce : fondu + très léger zoom (supprimée si reduce_motion).
## delay_s permet une cascade d'entrée (distribution des cartes).
func gentle_appear(node: Control, delay_s: float = 0.0) -> void:
	if reduce_motion:
		return
	node.modulate.a = 0.0
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2(0.92, 0.92)
	var tw := node.create_tween()
	if delay_s > 0.0:
		tw.tween_interval(delay_s)
	tw.set_parallel(true)
	tw.tween_property(node, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

## Fondu de sortie puis libération du contrôle (supprimé si reduce_motion :
## libération immédiate, sans fondu).
func gentle_release(node: Control, delay_s: float = 0.0) -> void:
	if reduce_motion:
		node.queue_free()
		return
	var tw := node.create_tween()
	if delay_s > 0.0:
		tw.tween_interval(delay_s)
	tw.tween_property(node, "modulate:a", 0.0, 0.25).set_ease(Tween.EASE_IN)
	tw.tween_callback(node.queue_free)
