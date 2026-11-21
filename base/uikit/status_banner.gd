class_name StatusBanner
extends PanelContainer
## Bandeau de notification dédié (messages de statut des jeux).
## Remplace l'ancien label nu logé sous les pastilles de progression — la
## colonne principale étroite limitait le message à la largeur des pastilles.
## Ici : bandeau pleine largeur étendue (max ~86 % de la surface, min 560 px),
## padding généreux, icône + texte centrés, teinte selon le ton (neutre /
## succès / encourageant). Jamais de rouge punitif ni de mot interdit.

enum Tone { NEUTRAL, SUCCESS, ENCOURAGE }

const _ICON_BY_TONE := {
	Tone.NEUTRAL: "ℹ️",
	Tone.SUCCESS: "✨",
	Tone.ENCOURAGE: "💫",
}

var _icon_label: Label
var _text_label: Label

func _init() -> void:
	# Composition interne : HBox centré [icône] [texte]
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 16)
	add_child(hb)

	_icon_label = Label.new()
	_icon_label.text = ""
	_icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(_icon_label)

	_text_label = Label.new()
	_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hb.add_child(_text_label)

	set_tone(Tone.NEUTRAL)

	# Le bandeau réserve sa place même vide (pas de saut de layout), mais
	# reste invisible tant qu'aucun message n'est posé.
	visible = false
	custom_minimum_size.y = 0

## Affiche un message. text vide → bandeau masqué (place conservée).
func show_message(text: String, icon: String = "", tone: Tone = Tone.NEUTRAL) -> void:
	if text.is_empty():
		visible = false
		return
	visible = true
	_text_label.text = text
	_icon_label.text = icon if not icon.is_empty() else _ICON_BY_TONE.get(tone, "")
	_icon_label.visible = not _icon_label.text.is_empty()
	set_tone(tone)

## Texte courant du bandeau (pour les tests et le diagnostic).
func message_text() -> String:
	return _text_label.text

func set_tone(tone: Tone) -> void:
	var sb := StyleBoxFlat.new()
	match tone:
		Tone.SUCCESS:
			sb.bg_color = ThemeService.GOOD_SOFT
			sb.border_color = ThemeService.GOOD
			_text_label.add_theme_color_override("font_color", ThemeService.GOOD)
		Tone.ENCOURAGE:
			sb.bg_color = ThemeService.WARN_SOFT
			sb.border_color = ThemeService.WARN
			_text_label.add_theme_color_override("font_color", ThemeService.WARN)
		_:
			sb.bg_color = ThemeService.SURFACE
			sb.border_color = ThemeService.BORDER
			_text_label.add_theme_color_override("font_color", ThemeService.INK)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(int(Tuning.UI_CORNER_RADIUS_SMALL))
	sb.content_margin_left = 28.0
	sb.content_margin_right = 28.0
	sb.content_margin_top = 18.0
	sb.content_margin_bottom = 18.0
	add_theme_stylebox_override("panel", sb)
	# Typo : gras pour le message, taille corps, haute lisibilité Andika.
	ThemeService.style_label(_text_label, Tuning.FONT_SIZE_BODY, _text_label.get_theme_color("font_color"), true)
	ThemeService.style_label(_icon_label, Tuning.FONT_SIZE_BODY + 4, ThemeService.INK)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		# Largeur généreuse : 86 % du parent, plancher 560 px — le message ne
		# vit PLUS jamais dans la colonne étroite des pastilles.
		var parent_w: float = get_parent_control().size.x if get_parent_control() != null else 0.0
		if parent_w > 0.0:
			custom_minimum_size.x = maxf(560.0, parent_w * 0.86)
