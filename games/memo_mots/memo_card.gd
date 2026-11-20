class_name MemoCard
extends Button
## Carte de Mémo-Mots : dos illustré (motif bulle), retournement animé
## (demi-rotation horizontale, la face change au milieu du mouvement),
## mot lu à voix haute au retournement (géré par le jeu).
## Mode homophone (niveau 3) : une carte porte une phrase à trou, l'autre le mot qui convient.
## Toutes les animations sont supprimées si ThemeService.reduce_motion.

signal card_flipped(card: MemoCard)
signal flip_finished(card: MemoCard)

var data: Dictionary = {}
var side: String = "a"
var is_matched: bool = false
var _face_up: bool = false
var _flip_tween: Tween = null

static func new_card(item: Dictionary, card_side: String, card_size: float = 216.0) -> MemoCard:
	var card := MemoCard.new()
	card.data = item
	card.side = card_side
	card.custom_minimum_size = Vector2(card_size, card_size)
	card.flip_down()
	card.pivot_offset = Vector2(cardSizeHalf(card_size), cardSizeHalf(card_size))
	card.pressed.connect(func() -> void:
		if not card._face_up and not card.is_matched:
			card.card_flipped.emit(card))
	return card

static func cardSizeHalf(s: float) -> float:
	return s * 0.5

func pair_id() -> String:
	return str(data.get("pair_id", ""))

func display_word() -> String:
	var key := "card_a" if side == "a" else "card_b"
	var card_data: Dictionary = data.get(key, {})
	return str(card_data.get("text", ""))

func audio_urls() -> Dictionary:
	var key := "card_a" if side == "a" else "card_b"
	var card_data: Dictionary = data.get(key, {})
	return card_data.get("audio", {})

func flip_up() -> void:
	_face_up = true
	_animate_flip()

func flip_down() -> void:
	_face_up = false
	# sans animation (mise en place initiale, retour après délai) : application directe
	_apply_face()

## Retournement animé : la carte se rétrécit sur X jusqu'à 0, la face change,
## puis elle se redéploie. Douce, courte (0,26 s), sans secousse.
func _animate_flip() -> void:
	if _flip_tween != null and _flip_tween.is_running():
		return
	if ThemeService.reduce_motion:
		_apply_face()
		flip_finished.emit(self)
		return
	pivot_offset = size * 0.5
	_kill_flip_tween()
	_flip_tween = create_tween()
	_flip_tween.tween_property(self, "scale:x", 0.0, 0.13) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_flip_tween.tween_callback(func() -> void: _apply_face())
	_flip_tween.tween_property(self, "scale:x", 1.0, 0.13) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_flip_tween.tween_callback(func() -> void: flip_finished.emit(self))

func _kill_flip_tween() -> void:
	if _flip_tween != null and _flip_tween.is_running():
		_flip_tween.kill()
	_flip_tween = null

func _apply_face() -> void:
	var key := "card_a" if side == "a" else "card_b"
	var card_data: Dictionary = data.get(key, {})
	var text := str(card_data.get("text", ""))
	# face cachée : dos uni ; face visible : le texte (mot ou phrase courte)
	if not _face_up:
		text = ""
	add_theme_font_override("font", ThemeService.font_bold())
	var fs := Tuning.FONT_SIZE_TILE if text.length() <= 6 else int(Tuning.FONT_SIZE_TILE_SMALL * 0.8)
	add_theme_font_size_override("font_size", fs)
	add_theme_color_override("font_color", ThemeService.INK)
	add_theme_color_override("font_hover_color", ThemeService.INK)
	add_theme_color_override("font_pressed_color", ThemeService.INK)
	add_theme_color_override("font_focus_color", ThemeService.INK)
	add_theme_color_override("font_disabled_color", ThemeService.INK)
	var sb := StyleBoxFlat.new()
	if is_matched:
		sb.bg_color = ThemeService.GOOD_SOFT
		sb.border_color = ThemeService.GOOD
	elif _face_up:
		sb.bg_color = ThemeService.SURFACE
		sb.border_color = ThemeService.ACCENT
	else:
		sb.bg_color = ThemeService.CARD_BACK
		sb.border_color = ThemeService.ACCENT
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(int(Tuning.UI_CORNER_RADIUS_SMALL))
	add_theme_stylebox_override("normal", sb)
	add_theme_stylebox_override("hover", sb)
	add_theme_stylebox_override("pressed", sb)
	add_theme_stylebox_override("disabled", sb)
	self.text = text
	# le dos porte un motif bulle dessiné ; la face reste sobre et lisible
	for c in get_children():
		if c is MemoCardBack:
			c.queue_free()
	if not _face_up and not is_matched:
		var back := MemoCardBack.new()
		back.set_anchors_preset(Control.PRESET_FULL_RECT)
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(back)

func mark_matched() -> void:
	is_matched = true
	disabled = true
	focus_mode = Control.FOCUS_NONE
	_apply_face()
	ThemeService.success_pulse(self)

## Reste figée (petit flottement vertical) le temps que la voix lise le mot —
## l'enfant associe l'écrit et l'oral sans être pressé.
func hold_attention() -> void:
	if ThemeService.reduce_motion:
		return
	pivot_offset = size * 0.5
	var tw := create_tween()
	tw.tween_property(self, "position:y", position.y - 6.0, 0.22) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(self, "position:y", position.y, 0.22) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

## La carte s'est envolée vers la pastille de progression : fondu de sortie.
func fly_away() -> void:
	disabled = true
	focus_mode = Control.FOCUS_NONE
	ThemeService.gentle_release(self, 0.15)

## Retourne la carte en douceur après un délai (paire non trouvée, sans pénalité).
## Le délai lui-même reste géré par le jeu (Tuning.MEMO_FLIP_BACK_MS).
func animated_flip_down() -> void:
	if ThemeService.reduce_motion:
		flip_down()
		return
	pivot_offset = size * 0.5
	_kill_flip_tween()
	_flip_tween = create_tween()
	_flip_tween.tween_property(self, "scale:x", 0.0, 0.13) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_flip_tween.tween_callback(func() -> void: flip_down())
	_flip_tween.tween_property(self, "scale:x", 1.0, 0.13) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

## Dos de carte : fond accent doux + bulles dessinées (jamais un « ? » nu).
## Image décorative pure : aucune interaction, aucune lecture d'écran parasite.
class MemoCardBack:
	extends Control
	func _draw() -> void:
		var w := size.x
		var h := size.y
		# grosses bulles douces dans les coins
		draw_circle(Vector2(w * 0.22, h * 0.24), w * 0.13, ThemeService.ACCENT)
		draw_circle(Vector2(w * 0.78, h * 0.3), w * 0.09, ThemeService.ACCENT.lightened(0.25))
		draw_circle(Vector2(w * 0.3, h * 0.76), w * 0.1, ThemeService.ACCENT.lightened(0.25))
		draw_circle(Vector2(w * 0.72, h * 0.74), w * 0.14, ThemeService.ACCENT)
		# petite étoile centrale (dessin, pas du texte)
		var c := Vector2(w * 0.5, h * 0.5)
		var r := w * 0.16
		var pts := PackedVector2Array([
			c + Vector2(0, -r), c + Vector2(r * 0.28, -r * 0.28),
			c + Vector2(r, 0), c + Vector2(r * 0.28, r * 0.28),
			c + Vector2(0, r), c + Vector2(-r * 0.28, r * 0.28),
			c + Vector2(-r, 0), c + Vector2(-r * 0.28, -r * 0.28),
		])
		draw_colored_polygon(pts, ThemeService.SURFACE)
