class_name TimeGauge
extends Control
## Jauge calme du temps actif : arc de soleil qui se déploie doucement, sans chiffres.
## Chiffres uniquement si a11y.show_time_digits est vrai.

const SUN := Color("ffb703")
const MOON := Color("5f7ce0")
const TRACK := Color("e6e6f5")

var _arc: float = 0.0

func _process(_delta: float) -> void:
	_arc = SessionTimer.progress_ratio()
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - 8.0
	# piste
	draw_arc(center, radius, 0, TAU, 64, TRACK, 10.0, true)
	# progression : soleil (desktop/jour) — palette calme, jamais alarmiste
	var color := SUN if SessionTimer.is_active() else MOON
	if _arc > 0.01:
		draw_arc(center, radius, -PI / 2.0, -PI / 2.0 + TAU * _arc, 64, color, 10.0, true)
	# petit disque central
	draw_circle(center, radius * 0.45, ThemeService.SURFACE)
	draw_circle(center, radius * 0.34, color.lerp(ThemeService.SURFACE, 0.35))
	if SessionTimer.show_digits():
		var minutes := SessionTimer.active_ms() / 60000.0
		var txt := "%d" % int(minutes)
		var f := ThemeService.font_bold()
		var fs := int(Tuning.FONT_SIZE_BODY * 0.6)
		var m := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		draw_string(f, center + Vector2(-m.x * 0.5, m.y * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ThemeService.INK)
