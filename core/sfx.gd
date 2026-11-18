class_name Sfx
extends RefCounted
## Effets sonores synthétiques du feedback (mode LOCAL uniquement, hors web :
## sur le web tout l'audio passe par la page hôte via Bridge.play_audio, protocole inchangé).
## Petites formules musicales très courtes et douces — jamais alarmistes.
## Respecte ThemeService.music_enabled (a11y.music) : tout est silencieux si faux.

## Petit carillon montant de réussite (tierce do-mi-sol lumineuse).
static func success_chime() -> void:
	_arpeggio([523.25, 659.25, 783.99], 0.09, 0.14)

## Cloche douce pour une paire trouvée (mémo, duo) : note + quinte tenue.
static func pair_bell() -> void:
	_tone(587.33, 0.28)
	_tone(880.0, 0.34, 0.05)

## Clic doux et neutre de retournement / manipulation (pas un jugement).
static func soft_flip() -> void:
	_tone(392.0, 0.07, 0.0, 9000.0)

## Petit roulis de fin de partie : trois notes descendantes très douces, warm.
static func celebration() -> void:
	_arpeggio([783.99, 659.25, 523.25], 0.11, 0.2, 0.0, true)

static func _enabled() -> bool:
	return ThemeService.music_enabled and AudioService.mode == AudioService.Mode.LOCAL

## Note sinusoïdale avec enveloppe triangulaire douce, échantillonnée à la volée.
static func _tone(freq: float, duration: float, delay_s: float = 0.0, rate: int = 22050, warm: bool = false) -> void:
	if not _enabled():
		return
	var samples := int(duration * rate)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var amp := 24000.0 if not warm else 21000.0
	for i in samples:
		var t := float(i) / rate
		var env := sin(PI * t / duration)  # enveloppe triangulaire douce
		var v := int(amp * env * sin(TAU * freq * t))
		if warm:
			v += int(amp * 0.25 * env * sin(TAU * freq * 2.0 * t))
		data.encode_s16(i * 2, v)
	_play_wav(data, rate, delay_s)

## Trois notes enchaînées avec un léger décalage (arpège).
static func _arpeggio(freqs: Array, note_dur: float, gap_s: float, first_delay_s: float = 0.0, warm: bool = false) -> void:
	for i in freqs.size():
		_tone(float(freqs[i]), note_dur, first_delay_s + i * gap_s, 22050, warm)

static func _play_wav(data: PackedByteArray, rate: int, delay_s: float) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var player := AudioStreamPlayer.new()
	player.volume_db = Tuning.SFX_VOLUME_DB
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	player.stream = stream
	tree.root.add_child(player)
	if delay_s > 0.0:
		var timer := tree.create_timer(delay_s)
		timer.timeout.connect(func() -> void:
			if is_instance_valid(player):
				player.play())
	else:
		player.play()
	player.finished.connect(player.queue_free)
