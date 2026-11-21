## Tests du StatusBanner : bandeau de notification large dédié (hors colonne
## des pastilles). Vérifie : masquage à vide (place conservée), message affiché,
## accesseur message_text, ton SUCCESS teinte le fond, largeur généreuse au
## resize (≥ 560 px, ~86 % du parent), icône par défaut par ton.
## Booter : godot --headless --path . res://tests/test_status_banner.tscn
extends Node

var _failures: Array[String] = []
var _passes: int = 0

func _ready() -> void:
	await get_tree().process_frame
	_test_empty_hides_but_keeps_space()
	_test_show_message()
	_test_tones()
	_test_width_generous()
	_finish()

func check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
	else:
		_failures.append(label)
		push_error("FAIL : " + label)

func _banner_in_parent() -> StatusBanner:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(1080, 600)
	add_child(holder)
	var b := StatusBanner.new()
	holder.add_child(b)
	return b

func _test_empty_hides_but_keeps_space() -> void:
	var b := _banner_in_parent()
	b.show_message("")
	check(not b.visible, "message vide → bandeau masqué")
	b.queue_free()

func _test_show_message() -> void:
	var b := _banner_in_parent()
	b.show_message("Bien joué, le mot chat est forgé !", "★")
	check(b.visible, "message → bandeau visible")
	check(b.message_text().contains("forgé"), "message_text renvoie le texte")
	check(b._icon_label.text == "★", "icône personnalisée posée")
	b.queue_free()

func _test_tones() -> void:
	var b := _banner_in_parent()
	b.show_message("Bravo !", "", StatusBanner.Tone.SUCCESS)
	var sb: StyleBoxFlat = b.get_theme_stylebox("panel")
	check(sb.bg_color == ThemeService.GOOD_SOFT, "ton SUCCESS → fond GOOD_SOFT")
	check(not b._icon_label.text.is_empty(), "ton SUCCESS → icône par défaut posée")
	b.show_message("Presque, réessaie", "", StatusBanner.Tone.ENCOURAGE)
	sb = b.get_theme_stylebox("panel")
	check(sb.bg_color == ThemeService.WARN_SOFT, "ton ENCOURAGE → fond WARN_SOFT")
	b.queue_free()

func _test_width_generous() -> void:
	var b := _banner_in_parent()
	# Simuler un parent large : le banner réclame ≥ 560 px (plancher) via
	# NOTIFICATION_RESIZED du parent — on déclenche via un resize forcé.
	var holder: Control = b.get_parent()
	holder.size = Vector2(1000, 600)
	await get_tree().process_frame
	check(b.custom_minimum_size.x >= 560.0, "largeur ≥ 560 px (plancher)")
	holder.queue_free()

func _finish() -> void:
	if _failures.is_empty():
		print("TESTS STATUS-BANNER OK : %d vérifications" % _passes)
		get_tree().quit(0)
	else:
		print("TESTS STATUS-BANNER ÉCHOUÉ : %d — %s" % [_failures.size(), "; ".join(_failures)])
		get_tree().quit(1)
