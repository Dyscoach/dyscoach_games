extends Node
## Lecture des consignes vocales. Deux modes :
## - "host" (défaut) : le jeu demande à la page hôte de jouer le fichier audio (play_audio),
##   la hôte répond audio_ended. Sur le web, aucun son ne peut être généré ni décodé ici.
## - "local" : petits effets sonores embarqués générés (sinusoïdes) pour le feedback, hors web.
## Si aucun audio n'arrive dans AUDIO_TIMEOUT_MS : signal audio_missing → le jeu continue
## (mot affiché en grand texte, événement error {code:"audio_missing"} sans planter).

signal audio_missing(id: String, kind: String)
signal audio_started(id: String)

enum Mode { HOST, LOCAL }

var mode: int = Mode.HOST
var _pending: Dictionary = {}      # id -> {kind, started_ms}
var _local_player: AudioStreamPlayer = null
var _current_id: String = ""

func _ready() -> void:
	if not OS.has_feature("web"):
		mode = Mode.LOCAL
		_local_player = AudioStreamPlayer.new()
		_local_player.volume_db = Tuning.SFX_VOLUME_DB
		add_child(_local_player)

func set_host_mode() -> void:
	mode = Mode.HOST

## Joue un audio de consigne (mot, son isolé, phrase...). kind ∈ prompt|word|feedback
func speak(id: String, url: String, kind: String = "prompt") -> void:
	if url.is_empty():
		_fail_missing(id, kind)
		return
	if mode == Mode.HOST and Bridge.is_web():
		_current_id = id
		_pending[id] = {"kind": kind, "started_ms": Time.get_ticks_msec()}
		Bridge.send_play_audio(id, url, kind)
		audio_started.emit(id)
		_arm_timeout(id, kind)
	elif mode == Mode.LOCAL and _local_player != null:
		# pas de fichier local disponible : retour visuel suffit ; on ne bloque pas
		audio_started.emit(id)
		_simulate_end(id)
	else:
		_fail_missing(id, kind)

func _simulate_end(id: String) -> void:
	await get_tree().create_timer(0.4).timeout
	Bridge.audio_ended.emit(id)

func _arm_timeout(id: String, kind: String) -> void:
	await get_tree().create_timer(Tuning.AUDIO_TIMEOUT_MS / 1000.0).timeout
	if _pending.has(id):
		_pending.erase(id)
		_fail_missing(id, kind)

func _fail_missing(id: String, kind: String) -> void:
	Bridge.send_error("audio_missing", "Audio indisponible (%s)" % kind)
	audio_missing.emit(id, kind)

## Notification de la hôte : audio terminé (reçu via Bridge.audio_ended).
func on_host_audio_ended(_id: String, _kind: String = "") -> void:
	# la hôte confirme la fin d'un audio ; les jeux écoutent host_audio_finished si besoin
	pass

signal host_audio_finished(id: String, kind: String)

func stop_all() -> void:
	_pending.clear()
	if Bridge.is_web():
		Bridge.send_stop_audio()
	_current_id = ""

## Petit effet local (hors web uniquement) : bip doux de réussite, note simple.
func play_success_chime() -> void:
	_play_tone(660.0, 0.12)

func play_gentle_pop() -> void:
	_play_tone(440.0, 0.08)

func _play_tone(freq: float, duration: float) -> void:
	if _local_player == null:
		return
	var rate := 22050
	var samples := int(duration * rate)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in samples:
		var t := float(i) / rate
		var env := sin(PI * t / duration)  # enveloppe triangulaire douce
		var v := int(32000.0 * env * sin(TAU * freq * t))
		data.encode_s16(i * 2, v)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	_local_player.stream = stream
	_local_player.play()

# --- branchement sur la hôte ---
func _connect_bridge() -> void:
	Bridge.audio_ended.connect(on_host_audio_ended)

func _enter_tree() -> void:
	# Bridge est un autoload défini avant : connexion différée d'une frame pour l'ordre d'initialisation
	call_deferred("_connect_bridge")
