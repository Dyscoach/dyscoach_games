class_name CarnetScreen
extends Control
## Carnet des Sonimaux : grille de cartes, une par créature.
## Stade 0 = silhouette ; 1 = œuf ; 2 = jeune ; 3 = adulte. Les stades sont DÉCIDÉS par la
## plateforme : le carnet les affiche exactement, il ne les calcule pas.
## Habillage sobre pour 12-14/15-16 ans : « carnet de découvertes » (mêmes données).

signal closed

static func build(collection_state: Dictionary, age_band: String) -> CarnetScreen:
	var screen := CarnetScreen.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.2, 0.2, 0.3, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(center)
	var panel := PanelContainer.new()
	ThemeService.style_panel(panel)
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	vb.custom_minimum_size = Vector2(900, 0)
	panel.add_child(vb)
	var sober := age_band == "12-14" or age_band == "15-16"
	var title := Label.new()
	title.text = "Carnet de découvertes" if sober else Strings.CARNET
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeService.style_label(title, Tuning.FONT_SIZE_TITLE, ThemeService.INK, true)
	vb.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(860, 900)
	vb.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	var creatures: Array = collection_state.get("creatures", [])
	for c in creatures:
		grid.add_child(_creature_card(c, sober))
	var close := UIKit.big_button(Strings.CONTINUE, func() -> void:
		screen.closed.emit()
		screen.queue_free())
	var wrap := CenterContainer.new()
	wrap.add_child(close)
	vb.add_child(wrap)
	return screen

static func _creature_card(c: Dictionary, sober: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = ThemeService.SURFACE
	sb.border_color = ThemeService.BORDER
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(int(Tuning.UI_CORNER_RADIUS_SMALL))
	sb.content_margin_left = 16.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(200, 240)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)
	var art := CreatureArt.new()
	art.stage = int(c.get("stage", 0))
	art.sober = sober
	art.custom_minimum_size = Vector2(120, 120)
	var art_wrap := CenterContainer.new()
	art_wrap.add_child(art)
	vb.add_child(art_wrap)
	var name_lbl := Label.new()
	name_lbl.text = str(c.get("name", ""))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeService.style_label(name_lbl, int(Tuning.FONT_SIZE_BODY * 0.6), ThemeService.INK, true)
	vb.add_child(name_lbl)
	var sound_lbl := Label.new()
	sound_lbl.text = "/ %s /" % str(c.get("sound_label", ""))
	sound_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeService.style_label(sound_lbl, int(Tuning.FONT_SIZE_BODY * 0.5), ThemeService.INK_SOFT)
	vb.add_child(sound_lbl)
	return panel

class CreatureArt:
	extends Control
	## Dessin simple d'une créature selon son stade : 0 silhouette, 1 œuf, 2 jeune, 3 adulte.
	## Formes vectorielles créées dans le projet (aucune ressemblance avec une licence).
	var stage: int = 0
	var sober: bool = false

	func _draw() -> void:
		var c := size * 0.5
		var col := ThemeService.ACCENT if not sober else ThemeService.INK_SOFT
		match stage:
			0:
				# silhouette : forme sombre uniforme
				draw_circle(c, size.x * 0.32, Color("8a8ba0"))
				draw_circle(c + Vector2(0, -size.y * 0.22), size.x * 0.16, Color("8a8ba0"))
			1:
				# œuf
				draw_circle(c, size.x * 0.28, col.lightened(0.5))
				draw_arc(c, size.x * 0.28, 0, TAU, 32, col, 4.0)
			2:
				# jeune : petit corps + yeux
				draw_circle(c, size.x * 0.24, col.lightened(0.2))
				draw_circle(c + Vector2(-8, -6), 4, ThemeService.INK)
				draw_circle(c + Vector2(8, -6), 4, ThemeService.INK)
			3:
				# adulte : corps + yeux + petites oreilles
				draw_circle(c, size.x * 0.3, col)
				draw_circle(c + Vector2(-10, -6), 5, ThemeService.INK)
				draw_circle(c + Vector2(10, -6), 5, ThemeService.INK)
				draw_circle(c + Vector2(-18, -26), 7, col)
				draw_circle(c + Vector2(18, -26), 7, col)
