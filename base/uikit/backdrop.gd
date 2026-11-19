class_name Backdrop
extends Control
## Décor vectoriel partagé : un univers par jeu, dessiné dans _draw().
## Statique volontairement (fond calme, DYS) : le mouvement vit dans le jeu et la mascotte.
## Le HAUT reste clair dans tous les univers (lisibilité titres/consignes, contraste INK AA).
## Mode sobre (12-14 / 15-16) : simple dégradé discret, pas de silhouettes.
## Décoratif : mouse_filter IGNORE, aucune information portée par le décor.

const UNIVERSES := {
	"jardin": {"top": Color("FDFCFF"), "bottom": Color("E7F3E1"), "layers": [Color("C7E4BC"), Color("D8EDD0")], "orb": Color("FFB703"), "halo": Color("FFD166")},
	"etang": {"top": Color("F9FBFF"), "bottom": Color("E1EEF6"), "layers": [Color("B4D3EA"), Color("C8DFEF")], "orb": Color("FFE9A8"), "halo": Color("FFF3C4")},
	"forge": {"top": Color("FFFDF9"), "bottom": Color("F5E4CF"), "layers": [Color("E3CDAC"), Color("DCC29B")], "orb": Color("F3B36B"), "halo": Color("F9D9A8")},
	"scene": {"top": Color("FFFBFF"), "bottom": Color("EFE0F0"), "layers": [Color("E3CDF0"), Color("D9C3EA")], "orb": Color("FFE0B8"), "halo": Color("FFF0DC")},
	"campagne": {"top": Color("FAFBF7"), "bottom": Color("E7EFD9"), "layers": [Color("C0E0B1"), Color("D0E8C3")], "orb": Color("FFB703"), "halo": Color("FFD166")},
	"nuit": {"top": Color("F6F7FF"), "bottom": Color("DEE4F2"), "layers": [Color("C6CDE5"), Color("D5DBEC")], "orb": Color("F2F0E4"), "halo": Color("FFFFFF"), "stars": true},
	"espace": {"top": Color("F8F7FF"), "bottom": Color("E3E2F4"), "layers": [Color("CBC6E9"), Color("D8D4EF")], "orb": Color("F2C9A0"), "halo": Color("F9E0C8"), "stars": true},
}

var universe: String = "jardin"
var sober: bool = false

func setup(universe_id: String, sober_mode: bool = false) -> void:
	universe = universe_id if UNIVERSES.has(universe_id) else "jardin"
	sober = sober_mode
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	var u: Dictionary = UNIVERSES[universe]
	var w := size.x
	var h := size.y
	if w <= 1.0 or h <= 1.0:
		return
	# ciel : dégradé vertical doux (haut clair → teinte basse pastel)
	var top: Color = u["top"]
	var bottom: Color = u["bottom"]
	draw_polygon(
		PackedVector2Array([Vector2.ZERO, Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([top, top, bottom, bottom])
	)
	if sober:
		return  # ados : dégradé seul, pas de figuratif
	# astre (soleil / lune / planète) : disque + halo large très transparent
	var orb_c := Vector2(w * 0.82, h * 0.14)
	var halo_c: Color = u["halo"]
	draw_circle(orb_c, 84.0, Color(halo_c, 0.22))
	draw_circle(orb_c, 46.0, u["orb"])
	# étoiles discrètes (nuit / espace) : points fixes, jamais clignotants
	if bool(u.get("stars", false)):
		var ink := Color(0.35, 0.38, 0.55, 0.30)
		var abscissas := [0.08, 0.22, 0.35, 0.48, 0.62, 0.75, 0.9]
		var i := 0
		for fx in abscissas:
			var fy := 0.06 + 0.05 * float((i * 3) % 4)
			draw_circle(Vector2(w * fx, h * fy), 4.0 + float(i % 3), ink)
			i += 1
	# collines : deux arcs bas, pastel, du plus clair (loin) au plus soutenu (proche)
	var layers: Array = u["layers"]
	var specs := [
		{"x": 0.22, "r": w * 0.42, "dy": 0.985},
		{"x": 0.78, "r": w * 0.38, "dy": 1.0},
	]
	for li in specs.size():
		var s: Dictionary = specs[li]
		var col: Color = layers[mini(li, layers.size() - 1)]
		draw_circle(Vector2(w * float(s["x"]), h * float(s["dy"]) + float(s["r"]) * 0.55), float(s["r"]), col)
