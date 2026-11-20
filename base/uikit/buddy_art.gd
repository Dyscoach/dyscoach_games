class_name BuddyArt
extends Control
## Dessins vectoriels des compagnons/héros de jeu, teintés par le thème courant.
## Trois héros (créature Sonimaux, tambour de Syllabo, balayage Radar) : chaque jeu
## montre ENFIN l'objet que son nom promet. Statique par défaut (DYS) — le mouvement
## reste porté par le jeu et Buddy. mouse_filter IGNORE : purement décoratif.

var kind: String = "creature"    # creature | drum | radar
var size_hint: float = 140.0     # côté de dessin utile avant application de la taille

static func make(kind_id: String, sober: bool = false, hint: float = 140.0) -> BuddyArt:
	var art := BuddyArt.new()
	art.kind = kind_id
	art.size_hint = hint
	art.custom_minimum_size = Vector2(hint * (0.66 if sober else 1.0), hint * (0.66 if sober else 1.0))
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.clip_contents = false
	return art

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 1.0 or h <= 1.0:
		return
	match kind:
		"creature":
			_draw_creature(w, h)
		"drum":
			_draw_drum(w, h)
		"radar":
			_draw_radar(w, h)

## Créature Sonimaux : corps rond + oreilles + yeux + joues — attachante, formes douces.
func _draw_creature(w: float, h: float) -> void:
	var c := Vector2(w * 0.5, h * 0.55)
	var r := minf(w, h) * 0.34
	var body: Color = ThemeService.ACCENT.lightened(0.22)
	var line: Color = ThemeService.ACCENT.darkened(0.2)
	# oreilles
	draw_circle(c + Vector2(-r * 0.62, -r * 0.95), r * 0.28, body)
	draw_circle(c + Vector2(r * 0.62, -r * 0.95), r * 0.28, body)
	draw_arc(c + Vector2(-r * 0.62, -r * 0.95), r * 0.28, 0, TAU, 24, line, 2.5)
	draw_arc(c + Vector2(r * 0.62, -r * 0.95), r * 0.28, 0, TAU, 24, line, 2.5)
	# corps
	draw_circle(c, r, body)
	draw_arc(c, r, 0, TAU, 40, line, 3.0)
	# ventre plus clair
	draw_circle(c + Vector2(0, r * 0.25), r * 0.62, body.lightened(0.35))
	# yeux (grands, ouverts : la créature « regarde » l'enfant)
	for ex in [-1.0, 1.0]:
		var p := c + Vector2(ex * r * 0.34, -r * 0.18)
		draw_circle(p, r * 0.13, ThemeService.INK)
		draw_circle(p + Vector2(r * 0.04, -r * 0.04), r * 0.045, Color.WHITE)
	# sourire
	draw_arc(c + Vector2(0, r * 0.08), r * 0.34, PI * 0.15, PI * 0.85, 12, ThemeService.INK, 3.0)
	# joues
	draw_circle(c + Vector2(-r * 0.62, r * 0.12), r * 0.12, Color(1.0, 0.62, 0.62, 0.35))
	draw_circle(c + Vector2(r * 0.62, r * 0.12), r * 0.12, Color(1.0, 0.62, 0.62, 0.35))
	# petites pattes
	draw_circle(c + Vector2(-r * 0.55, r * 0.92), r * 0.18, body)
	draw_circle(c + Vector2(r * 0.55, r * 0.92), r * 0.18, body)

## Tambour de Syllabo : caisse + peaux + cordes — remplace l'emoji 🥁.
func _draw_drum(w: float, h: float) -> void:
	var c := Vector2(w * 0.5, h * 0.52)
	var rw := minf(w, h) * 0.42     # demi-largeur
	var rh := rw * 0.62             # demi-hauteur
	var shell: Color = Color("F3B36B").darkened(0.1)
	var skin: Color = Color("FFF3DC")
	# corps du tambour (trapèze léger : plus large en haut)
	var body_pts := PackedVector2Array([
		c + Vector2(-rw, -rh), c + Vector2(rw, -rh),
		c + Vector2(rw * 0.82, rh), c + Vector2(-rw * 0.82, rh),
	])
	draw_colored_polygon(body_pts, shell)
	# peau supérieure (ellipse)
	draw_ellipse_filled(c + Vector2(0, -rh), rw, rh * 0.42, skin)
	draw_ellipse_outline(c + Vector2(0, -rh), rw, rh * 0.42, shell.darkened(0.25), 3.0)
	# cordes diagonales
	var cord: Color = shell.darkened(0.3)
	for k in 3:
		var t := 0.25 + 0.25 * k
		draw_line(c + Vector2(-rw + 2.0 * rw * t, -rh), c + Vector2(-rw * 0.82 + 1.64 * rw * 0.82 * t, rh), cord, 2.5)
	# base
	draw_line(c + Vector2(-rw * 0.82, rh), c + Vector2(rw * 0.82, rh), shell.darkened(0.35), 4.0)

## Balayage Radar : écran circulaire + anneaux + faisceau — l'univers « radar » rendu enfin visible.
func _draw_radar(w: float, h: float) -> void:
	var c := Vector2(w * 0.5, h * 0.5)
	var r := minf(w, h) * 0.46
	var screen_c: Color = Color("2E4A8A")
	var glow: Color = Color("8FD0A0")
	# écran
	draw_circle(c, r, screen_c)
	# anneaux concentriques
	for k in 3:
		draw_arc(c, r * (0.33 * (k + 1)), 0, TAU, 48, Color(screen_c, 1.0).lightened(0.18), 2.0)
	# croix discrète
	draw_line(c + Vector2(-r, 0), c + Vector2(r, 0), screen_c.lightened(0.15), 1.5)
	draw_line(c + Vector2(0, -r), c + Vector2(0, r), screen_c.lightened(0.15), 1.5)
	# faisceau (quart de disque dégradé simulé par arcs emboîtés)
	for k in 14:
		var a_from := -PI * 0.5 + PI * 0.5 * (float(k) / 14.0)
		var a_to := -PI * 0.5 + PI * 0.5 * (float(k + 1) / 14.0)
		var col := Color(glow, 0.05 + 0.16 * (1.0 - float(k) / 14.0))
		draw_circle_sector(c, r, a_from, a_to, col)
	# point de détection (une « cible » sur l'écran — décoratif)
	draw_circle(c + Vector2(r * 0.42, -r * 0.30), r * 0.06, glow)
	draw_arc(c + Vector2(r * 0.42, -r * 0.30), r * 0.11, 0, TAU, 20, glow, 2.0)
	# bordure
	draw_arc(c, r, 0, TAU, 48, ThemeService.ACCENT, 3.0)

# --- helpers ellipse (absents de l'API CanvasItem) ---

func draw_ellipse_filled(center: Vector2, rx: float, ry: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 36:
		var a := TAU * float(i) / 36.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, color)

func draw_ellipse_outline(center: Vector2, rx: float, ry: float, color: Color, width: float) -> void:
	for i in 36:
		var a1 := TAU * float(i) / 36.0
		var a2 := TAU * float(i + 1) / 36.0
		draw_line(center + Vector2(cos(a1) * rx, sin(a1) * ry), center + Vector2(cos(a2) * rx, sin(a2) * ry), color, width)

func draw_circle_sector(center: Vector2, radius: float, a_from: float, a_to: float, color: Color) -> void:
	var pts := PackedVector2Array([center])
	var steps := 8
	for i in steps + 1:
		var a := a_from + (a_to - a_from) * float(i) / float(steps)
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	draw_colored_polygon(pts, color)
