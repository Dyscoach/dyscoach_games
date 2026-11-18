class_name FloatingItem
extends Button
## Élément flottant de Chasse-Sons : affiche le mot (carte neutre, image si fournie
## par la plateforme plus tard), dérive lentement en sinus, éclot ou tremble doucement.
## Habillages : "bulles" (neutre) et "oeufs" (enfant) — dessins simples créés dans le projet.

signal item_tapped(item: FloatingItem)

var data: Dictionary = {}
var _anchor: Vector2 = Vector2.ZERO
var _drift_amp: float = 0.0
var _drift_period: float = 1.0
var _phase: float = 0.0
var _time: float = 0.0
var _found: bool = false
var _skin: String = "bulles"

static func new_item(item_data: Dictionary, item_size: Vector2, skin: String) -> FloatingItem:
	var item := FloatingItem.new()
	item.data = item_data
	item._skin = skin
	item.custom_minimum_size = item_size
	item.text = str(item_data.get("word", ""))
	item.add_theme_font_override("font", ThemeService.font_bold())
	var fs := Tuning.FONT_SIZE_TILE if item_size.x >= 170 else Tuning.FONT_SIZE_TILE_SMALL
	item.add_theme_font_size_override("font_size", int(fs * (0.72 if str(item_data.get("word", "")).length() > 4 else 0.9)))
	item.add_theme_color_override("font_color", ThemeService.INK)
	item.add_theme_color_override("font_hover_color", ThemeService.INK)
	item.add_theme_color_override("font_pressed_color", ThemeService.INK)
	item.add_theme_color_override("font_focus_color", ThemeService.INK)
	item.add_theme_color_override("font_disabled_color", ThemeService.INK)
	var sb := StyleBoxFlat.new()
	sb.bg_color = ThemeService.SURFACE
	sb.border_color = ThemeService.BORDER
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(int(Tuning.UI_CORNER_RADIUS))
	item.add_theme_stylebox_override("normal", sb)
	var hover := sb.duplicate()
	hover.bg_color = ThemeService.ACCENT_SOFT
	item.add_theme_stylebox_override("hover", hover)
	var pressed := sb.duplicate()
	pressed.bg_color = ThemeService.ACCENT_SOFT
	pressed.border_color = ThemeService.ACCENT
	item.add_theme_stylebox_override("pressed", pressed)
	item.pressed.connect(func() -> void:
		if not item._found:
			item.item_tapped.emit(item))
	return item

## Démare la dérive très lente autour d'une position d'ancrage (jamais de chute rapide).
func begin_drift(anchor: Vector2, amplitude: float, period: float, index: int) -> void:
	_anchor = anchor
	_drift_amp = amplitude
	_drift_period = maxf(period, 0.5)
	_phase = TAU * float(index) / 6.0

func _process(delta: float) -> void:
	if _drift_amp <= 0.0 or ThemeService.reduce_motion:
		return
	_time += delta
	var w := TAU * _time / _drift_period + _phase
	var offset := Vector2(cos(w), sin(w * 0.5)) * _drift_amp
	var half := size * 0.5
	position = _anchor + offset - half

## Bonne réponse : l'élément « éclot » (animation brève, sobre si thème ado).
func hatch() -> void:
	_found = true
	disabled = true
	focus_mode = Control.FOCUS_NONE
	var sb := StyleBoxFlat.new()
	sb.bg_color = ThemeService.GOOD_SOFT
	sb.border_color = ThemeService.GOOD
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(int(Tuning.UI_CORNER_RADIUS))
	add_theme_stylebox_override("disabled", sb)
	add_theme_color_override("font_disabled_color", ThemeService.GOOD)
	ThemeService.sparkle_burst(self, size * 0.5, ThemeService.GOOD)
	ThemeService.success_pulse(self)

## Erreur : tremblement doux (supprimé si reduce_motion) ; l'élément reste en place.
func gentle_shake() -> void:
	ThemeService.gentle_shake(self)
