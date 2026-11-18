class_name MemoCard
extends Button
## Carte de Mémo-Mots : face cachée (dos), retournement animé, mot lu au retournement.
## Mode homophone (niveau 3) : une carte porte une phrase à trou, l'autre le mot qui convient.

signal card_flipped(card: MemoCard)

var data: Dictionary = {}
var side: String = "a"
var is_matched: bool = false
var _face_up: bool = false

static func new_card(item: Dictionary, card_side: String) -> MemoCard:
	var card := MemoCard.new()
	card.data = item
	card.side = card_side
	card.custom_minimum_size = Vector2(216, 216)
	card.flip_down()
	card.pressed.connect(func() -> void:
		if not card._face_up and not card.is_matched:
			card.card_flipped.emit(card))
	return card

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
	_apply_face()

func flip_down() -> void:
	_face_up = false
	_apply_face()

func _apply_face() -> void:
	var key := "card_a" if side == "a" else "card_b"
	var card_data: Dictionary = data.get(key, {})
	var text := str(card_data.get("text", ""))
	# face cachée : dos uni ; face visible : le texte (mot ou phrase courte)
	if not _face_up:
		text = "?"
		if str(data.get("kind", "word_image")) == "homophone":
			text = "?"
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
		sb.bg_color = ThemeService.ACCENT_SOFT
		sb.border_color = ThemeService.BORDER
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(int(Tuning.UI_CORNER_RADIUS_SMALL))
	add_theme_stylebox_override("normal", sb)
	add_theme_stylebox_override("hover", sb)
	add_theme_stylebox_override("pressed", sb)
	add_theme_stylebox_override("disabled", sb)
	self.text = text

func mark_matched() -> void:
	is_matched = true
	disabled = true
	focus_mode = Control.FOCUS_NONE
	_apply_face()
	ThemeService.success_pulse(self)
