extends Node
## Événements de jeu : numérotation séquentielle + horodatage relatif.
## Aucune donnée personnelle : ni prénom, ni texte libre.

var _seq: int = 0
var _events_log: Array = []  # pour le panneau de debug uniquement, jamais envoyé ailleurs

func next_seq() -> int:
	_seq += 1
	return _seq

func record(name: String, data: Dictionary) -> void:
	_events_log.append({"name": name, "data": data, "seq": _seq, "t_ms": Time.get_ticks_msec()})

func log_snapshot() -> Array:
	return _events_log.duplicate(true)

func reset() -> void:
	_seq = 0
	_events_log.clear()

## Helper standard : envoie ET journalise un événement conforme au protocole.
func emit_event(name: String, data: Dictionary) -> void:
	record(name, data)
	Bridge.send_event(name, data)
