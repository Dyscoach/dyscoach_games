## Fumée du socle : boot de la scène principale sans erreur.
extends SceneTree

var _frames := 0

func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 30:
		print("SMOKE OK : enfants racine=", root.get_child_count())
		return true
	return false
