class_name Buddy
extends Control
## Mascotte réactive : réagit aux événements du jeu (bravo, presque, réflexion, repos),
## ne porte JAMAIS une information nécessaire — décorative et encourageante.
## Règles DYS : mouvement lent, non répétitif en boucle serrée, supprimé si reduce_motion,
## pas d'animation bloquante, taille modulée par la surface (jamais au-dessus du jeu).
## Mode sobre (12-14 / 15-16) : affichée mais discrète (plus petite, sans zigzag).

signal bubble_closed

enum Mood { IDLE, HAPPY, ENCOURAGE, THINK, REST }

const MOOD_FILL := {
	Mood.IDLE: Color("7EC8F2"),
	Mood.HAPPY: Color("FFC94D"),
	Mood.ENCOURAGE: Color("8ADFB4"),
	Mood.THINK: Color("B9A7F0"),
	Mood.REST: Color("A8B8D8"),
}

var mood: Mood = Mood.IDLE
var sober: bool = false
var _idle_t := 0.0
var _speech: Label = null
var _bubble: PanelContainer = null
var _pop_tw: Tween = null

func _init() -> void:
	custom_minimum_size = Vector2(120, 120)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false

func set_sober(s: bool) -> void:
	sober = s
	custom_minimum_size = Vector2(88, 88) if s else Vector2(120, 120)
	queue_redraw()

## Change d'humeur ; autoplay réduit si reduce_motion (l'humeur s'affiche quand même).
func react(m: Mood, say: String = "", duration_s: float = 2.2) -> void:
	mood = m
	queue_redraw()
	_pop()
	if say != "":
		_say(say)
	if duration_s > 0.0 and mood != Mood.IDLE:
		var tw := create_tween()
		tw.tween_interval(duration_s)
		tw.tween_callback(func() -> void:
			if mood == m:
				mood = Mood.IDLE
				queue_redraw())

func _pop() -> void:
	if ThemeService.reduce_motion:
		return
	pivot_offset = size * 0.5
	if _pop_tw != null and _pop_tw.is_running():
		_pop_tw.kill()
	# le pop reprend depuis l'échelle courante de la respiration et s'y remet :
	# la respiration _process réécrira scale à sa prochaine frame de toute façon.
	var tw := create_tween()
	_pop_tw = tw
	tw.tween_property(self, "scale", Vector2(1.14, 1.14), 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE, 0.14) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

## Respiration très lente en idle (1 cycle ≈ 3,6 s, amplitude 2 %) ;
## suspendue pendant un pop pour ne pas combattre le tween.
func _process(delta: float) -> void:
	if ThemeService.reduce_motion:
		return
	if _pop_tw != null and _pop_tw.is_running():
		return
	_idle_t += delta
	var s := 1.0 + 0.02 * sin(TAU * _idle_t / 3.6)
	pivot_offset = size * 0.5
	scale = Vector2(s, s)

func _say(text: String) -> void:
	if _bubble == null:
		_bubble = PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = ThemeService.SURFACE
		sb.border_color = ThemeService.BORDER
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(16)
		sb.content_margin_left = 14.0
		sb.content_margin_right = 14.0
		sb.content_margin_top = 8.0
		sb.content_margin_bottom = 8.0
		_bubble.add_theme_stylebox_override("panel", sb)
		_speech = Label.new()
		ThemeService.style_label(_speech, int(Tuning.FONT_SIZE_BODY * 0.55), ThemeService.INK)
		_speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_speech.custom_minimum_size = Vector2(240, 0)
		_bubble.add_child(_speech)
		add_child(_bubble)
	_speech.text = text
	_bubble.visible = true
	# la bulle reste DANS les limites du parent (clip_contents du jeu = viewport) :
	# ancrée au-dessus de la tête, décalée pour rester visible même bord gauche.
	_bubble.reset_size()
	_bubble.position = Vector2(clampf(size.x * 0.5 - 130.0, 4.0, maxf(4.0, get_parent_control().size.x - 264.0)) if get_parent_control() != null else size.x * 0.5 - 130.0, -_bubble_min_height())
	var tw := create_tween()
	tw.tween_interval(2.4)
	tw.tween_callback(func() -> void:
		_bubble.visible = false
		bubble_closed.emit())

func _bubble_min_height() -> float:
	return 70.0

func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5
	var fill: Color = MOOD_FILL.get(mood, MOOD_FILL[Mood.IDLE])
	# corps : sphère douce
	draw_circle(c, r, fill)
	draw_arc(c, r - 2.0, 0, TAU, 40, fill.darkened(0.18), 3.0)
	# yeux : deux pupilles (jamais fermées : la mascotte « regarde » l'enfant)
	var eye_y := c.y - r * 0.12
	var eye_dx := r * 0.34
	for ex in [-1.0, 1.0]:
		var p := Vector2(c.x + ex * eye_dx, eye_y)
		draw_circle(p, r * 0.11, ThemeService.INK)
		draw_circle(p + Vector2(r * 0.03, -r * 0.03), r * 0.035, Color.WHITE)
	# bouche selon l'humeur — forme TOUJOURS accompagnée d'icône/texte côté jeu
	match mood:
		Mood.HAPPY:
			draw_arc(Vector2(c.x, c.y + r * 0.08), r * 0.32, PI * 0.15, PI * 0.85, 12, ThemeService.INK, 3.5)
		Mood.THINK:
			draw_circle(Vector2(c.x, c.y + r * 0.22), r * 0.09, ThemeService.INK)
		Mood.REST:
			draw_arc(Vector2(c.x, c.y + r * 0.18), r * 0.2, PI * 0.2, PI * 0.8, 10, ThemeService.INK, 3.0)
		_:
			draw_arc(Vector2(c.x, c.y + r * 0.1), r * 0.26, PI * 0.12, PI * 0.88, 12, ThemeService.INK, 3.0)
	if not sober:
		# petit éclat au sommet (étincelle amicale, forme d'étoile 4 branches)
		var top := Vector2(c.x, c.y - r * 0.78)
		var pts := PackedVector2Array([
			top + Vector2(0, -7), top + Vector2(2, -2),
			top + Vector2(7, 0), top + Vector2(2, 2),
			top + Vector2(0, 7), top + Vector2(-2, 2),
			top + Vector2(-7, 0), top + Vector2(-2, -2),
		])
		draw_colored_polygon(pts, Color(1.0, 1.0, 1.0, 0.85))
		# joues roses discrètes (sauf humeurs pâles)
		if mood != Mood.REST:
			var cheek := Color(1.0, 0.62, 0.62, 0.35)
			draw_circle(Vector2(c.x - r * 0.55, c.y + r * 0.08), r * 0.12, cheek)
			draw_circle(Vector2(c.x + r * 0.55, c.y + r * 0.08), r * 0.12, cheek)
	# humeur THINK : petite bulle de réflexion au-dessus
	if mood == Mood.THINK and not sober:
		draw_circle(Vector2(c.x + r * 0.7, c.y - r * 1.05), 5.0, fill)
		draw_circle(Vector2(c.x + r * 0.95, c.y - r * 1.3), 3.5, fill)
