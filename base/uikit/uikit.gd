class_name UIKit
extends RefCounted
## Composants d'interface réutilisables : bouton large, carte, tuile, rangée responsive.
## Toutes les cibles respectent les tailles tactiles de Tuning (144 px, 200 px pour 6-8 ans).

## Bouton large avec icône texte (ex. haut-parleur) et cible tactile garantie.
static func big_button(text: String, on_pressed: Callable, min_size: Vector2 = Vector2(0, 0)) -> Button:
	var btn := Button.new()
	btn.text = text
	ThemeService.style_primary_button(btn, min_size)
	if min_size == Vector2.ZERO:
		btn.custom_minimum_size = Vector2(0, ThemeService.min_touch_target())
	btn.pressed.connect(on_pressed)
	return btn

## Bouton haut-parleur (réécoute), rond et large.
static func speaker_button(on_pressed: Callable, diameter: float = 0.0) -> Button:
	var d := diameter if diameter > 0 else maxf(ThemeService.min_touch_target(), 96.0)
	var btn := Button.new()
	btn.text = "🔊" if ThemeService.age_band != "12-14" and ThemeService.age_band != "15-16" else "Écouter"
	btn.add_theme_font_override("font", ThemeService.font_regular())
	btn.add_theme_font_size_override("font_size", int(d * 0.42))
	var sb := StyleBoxFlat.new()
	sb.bg_color = ThemeService.ACCENT
	sb.set_corner_radius_all(int(d / 2.0))
	btn.add_theme_stylebox_override("normal", sb)
	var sb2 := sb.duplicate()
	sb2.bg_color = ThemeService.ACCENT.darkened(0.15)
	btn.add_theme_stylebox_override("pressed", sb2)
	btn.custom_minimum_size = Vector2(d, d)
	btn.pressed.connect(on_pressed)
	return btn

## Carte surface blanche, bordure douce, coins arrondis.
static func card_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	ThemeService.style_panel(panel)
	return panel

## Tuile de graphème/mot : fond surface, gros texte, coins arrondis, état visuel propre.
static func tile(text: String, tile_size: Vector2) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = tile_size
	btn.add_theme_font_override("font", ThemeService.font_bold())
	btn.add_theme_font_size_override("font_size", _tile_font_size(text, tile_size))
	btn.add_theme_color_override("font_color", ThemeService.INK)
	btn.add_theme_color_override("font_hover_color", ThemeService.INK)
	btn.add_theme_color_override("font_pressed_color", ThemeService.INK)
	btn.add_theme_color_override("font_focus_color", ThemeService.INK)
	var sb := StyleBoxFlat.new()
	sb.bg_color = ThemeService.SURFACE
	sb.border_color = ThemeService.BORDER
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(int(Tuning.UI_CORNER_RADIUS_SMALL))
	btn.add_theme_stylebox_override("normal", sb)
	var hover := sb.duplicate()
	hover.bg_color = ThemeService.ACCENT_SOFT
	btn.add_theme_stylebox_override("hover", hover)
	var pressed := sb.duplicate()
	pressed.bg_color = ThemeService.ACCENT
	pressed.border_color = ThemeService.ACCENT
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.add_theme_stylebox_override("pressed", pressed)
	return btn

func _tile_font_size_placeholder() -> void:
	pass

static func _tile_font_size(text: String, tile_size: Vector2) -> int:
	var base := Tuning.FONT_SIZE_TILE if tile_size.x >= 180 else Tuning.FONT_SIZE_TILE_SMALL
	if text.length() >= 3:
		base = int(base * 0.66)
	return base

## Verrouille visuellement une tuile réussie (éclat discret + teinte positive).
static func mark_tile_success(tile: Button, parent: Control) -> void:
	tile.disabled = true
	tile.focus_mode = Control.FOCUS_NONE
	var sb := StyleBoxFlat.new()
	sb.bg_color = ThemeService.GOOD_SOFT
	sb.border_color = ThemeService.GOOD
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(int(Tuning.UI_CORNER_RADIUS_SMALL))
	tile.add_theme_stylebox_override("disabled", sb)
	tile.add_theme_color_override("font_disabled_color", ThemeService.GOOD)
	var center := tile.position + tile.size * 0.5
	ThemeService.sparkle_burst(parent, center, ThemeService.GOOD)
	ThemeService.success_pulse(tile)

## Retour visuel neutre pour une erreur : la tuile tremble doucement (supprimé si reduce_motion).
static func mark_tile_retry(tile: Button, parent: Control) -> void:
	ThemeService.gentle_shake(tile)

## Grille responsive d'éléments tactiles : nombre de colonnes selon la largeur utile.
static func columns_for_width(available_width: float, cell_size: float) -> int:
	var spacing := ThemeService.min_spacing()
	var per_row := int((available_width + spacing) / (cell_size + spacing))
	return maxi(per_row, 1)

## Bandeau d'instruction en haut d'un jeu : titre + sous-titre.
static func header(title: String, subtitle: String) -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeService.style_label(t, Tuning.FONT_SIZE_TITLE, ThemeService.INK, true)
	vb.add_child(t)
	var s := Label.new()
	s.text = subtitle
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeService.style_label(s, int(Tuning.FONT_SIZE_BODY * 0.8), ThemeService.INK_SOFT)
	vb.add_child(s)
	return vb
