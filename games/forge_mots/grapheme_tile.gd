class_name GraphemeTile
extends Button
## Tuile de graphème de Forge-Mots : sélection, lueur d'aide, verrouillage visuel.
## Cible tactile garantie (≥144 px, ≥200 px pour 6-8 ans via ThemeService).

signal tapped(tile: GraphemeTile)

var grapheme: String = ""
var locked: bool = false

static func new_tile(grapheme_text: String, tile_size: Vector2) -> GraphemeTile:
	var tile := GraphemeTile.new()
	tile.grapheme = grapheme_text
	tile.text = grapheme_text
	tile.custom_minimum_size = tile_size
	tile.add_theme_font_override("font", ThemeService.font_bold())
	var font_size := Tuning.FONT_SIZE_TILE
	if tile_size.x >= 180:
		font_size = Tuning.FONT_SIZE_TILE if grapheme_text.length() <= 2 else int(Tuning.FONT_SIZE_TILE * 0.66)
	else:
		font_size = Tuning.FONT_SIZE_TILE_SMALL if grapheme_text.length() <= 2 else int(Tuning.FONT_SIZE_TILE_SMALL * 0.66)
	tile.add_theme_font_size_override("font_size", font_size)
	tile.add_theme_color_override("font_color", ThemeService.INK)
	tile.add_theme_color_override("font_hover_color", ThemeService.INK)
	tile.add_theme_color_override("font_pressed_color", ThemeService.INK)
	tile.add_theme_color_override("font_focus_color", ThemeService.INK)
	var sb := StyleBoxFlat.new()
	sb.bg_color = ThemeService.SURFACE
	sb.border_color = ThemeService.BORDER
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(int(Tuning.UI_CORNER_RADIUS_SMALL))
	tile.add_theme_stylebox_override("normal", sb)
	var hover := sb.duplicate()
	hover.bg_color = ThemeService.ACCENT_SOFT
	tile.add_theme_stylebox_override("hover", hover)
	var pressed := sb.duplicate()
	pressed.bg_color = ThemeService.ACCENT_SOFT
	pressed.border_color = ThemeService.ACCENT
	tile.add_theme_stylebox_override("pressed", pressed)
	tile.pressed.connect(func() -> void: tile.tapped.emit(tile))
	return tile

func set_selected(selected: bool) -> void:
	var sb := StyleBoxFlat.new()
	if selected:
		sb.bg_color = ThemeService.ACCENT_SOFT
		sb.border_color = ThemeService.ACCENT
	else:
		sb.bg_color = ThemeService.SURFACE
		sb.border_color = ThemeService.BORDER
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(int(Tuning.UI_CORNER_RADIUS_SMALL))
	add_theme_stylebox_override("normal", sb)
	add_theme_stylebox_override("hover", sb)
	add_theme_stylebox_override("pressed", sb)

## Lueur d'aide : bordure accent pulsée quelques secondes (supprimée si reduce_motion).
func start_glow() -> void:
	if ThemeService.reduce_motion:
		set_selected(true)
		return
	var glow := StyleBoxFlat.new()
	glow.bg_color = ThemeService.ACCENT_SOFT
	glow.border_color = ThemeService.ACCENT
	glow.set_border_width_all(6)
	glow.set_corner_radius_all(int(Tuning.UI_CORNER_RADIUS_SMALL))
	var base := StyleBoxFlat.new()
	base.bg_color = ThemeService.SURFACE
	base.border_color = ThemeService.BORDER
	base.set_border_width_all(3)
	base.set_corner_radius_all(int(Tuning.UI_CORNER_RADIUS_SMALL))
	var tw := create_tween().set_loops(3)
	tw.tween_callback(func() -> void: add_theme_stylebox_override("normal", glow))
	tw.tween_interval(0.4)
	tw.tween_callback(func() -> void: add_theme_stylebox_override("normal", base))
	tw.tween_interval(0.2)

## Verrouille la tuile (déjà posée dans une case).
func lock_visual() -> void:
	locked = true
	disabled = true

class DropTarget:
	extends RefCounted
	var slot_index: int = 0
