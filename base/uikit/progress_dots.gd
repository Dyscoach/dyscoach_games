## Pastille de progression calme : un rond qui s'allume (vert) quand une étape est réussie.
## Jamais de chiffres ni de comparaison — la ligne se remplit au fil des réussites.
class_name ProgressDots
extends Control

var _total: int = 0
var _lit: int = 0
var _dot_r: float = 14.0
var _gap: float = 18.0

func setup(total: int) -> void:
	_total = maxi(total, 1)
	_dot_r = Tuning.PROGRESS_DOT_RADIUS
	_gap = Tuning.PROGRESS_DOT_GAP
	custom_minimum_size = Vector2(_total * (_dot_r * 2.0 + _gap) - _gap, _dot_r * 2.0)
	queue_redraw()

func light_next() -> void:
	if _lit < _total:
		_lit += 1
		queue_redraw()

func is_complete() -> bool:
	return _lit >= _total

func _draw() -> void:
	var y := size.y * 0.5
	var step := _dot_r * 2.0 + _gap
	for i in _total:
		var c := Vector2(step * i + _dot_r + _gap * 0.5, y)
		if i < _lit:
			draw_circle(c, _dot_r, ThemeService.GOOD)
			draw_circle(c, _dot_r * 0.55, ThemeService.GOOD_SOFT)
			# petite étoile discrète à l'intérieur (pas seulement la couleur)
			draw_circle(c, _dot_r * 0.22, ThemeService.GOOD)
		else:
			draw_circle(c, _dot_r, ThemeService.BORDER)
			draw_circle(c, _dot_r * 0.62, ThemeService.SURFACE)
