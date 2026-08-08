class_name SoundBank
extends RefCounted

## Набор звуков и фоновой музыки. Всё синтезируется один раз при запуске.

const CLICK := &"click"
const BUILD := &"build"
const DEMOLISH := &"demolish"
const DRONE := &"drone"
const FURNACE := &"furnace"
const RESEARCH := &"research"
const ACHIEVEMENT := &"achievement"
const METEOR := &"meteor"
const VICTORY := &"victory"
const DENIED := &"denied"

static var _effects: Dictionary[StringName, AudioStreamWAV] = {}
static var _music: AudioStreamWAV = null
static var _built: bool = false


static func build() -> void:
	if _built:
		return
	var start_usec: int = Time.get_ticks_usec()

	_effects[CLICK] = _click()
	_effects[BUILD] = _build_sound()
	_effects[DEMOLISH] = _demolish()
	_effects[DRONE] = _drone()
	_effects[FURNACE] = _furnace()
	_effects[RESEARCH] = _research()
	_effects[ACHIEVEMENT] = _achievement()
	_effects[METEOR] = _meteor()
	_effects[VICTORY] = _victory()
	_effects[DENIED] = _denied()
	_music = _lofi_loop()

	_built = true
	Log.info("Звук: %d эффектов и петля %.0f с за %.0f мс" % [
		_effects.size(),
		float(_music.data.size() / 2) / float(AudioLab.RATE),
		float(Time.get_ticks_usec() - start_usec) / 1000.0,
	])


static func effect(id: StringName) -> AudioStreamWAV:
	build()
	return _effects.get(id)


static func music() -> AudioStreamWAV:
	build()
	return _music


static func effect_ids() -> Array[StringName]:
	build()
	var ids: Array[StringName] = []
	for id: StringName in _effects:
		ids.append(id)
	return ids


## --- Эффекты ---------------------------------------------------------------

static func _click() -> AudioStreamWAV:
	var samples: PackedFloat32Array = AudioLab.silence(0.07)
	AudioLab.tone(samples, 0.0, AudioLab.NOTE_A4, 0.06, 0.25, 0.002)
	return AudioLab.to_stream(AudioLab.normalize(samples, 0.5))


static func _build_sound() -> AudioStreamWAV:
	# Тук установки плюс короткая восходящая пара нот: «встало на место».
	var samples: PackedFloat32Array = AudioLab.silence(0.4)
	AudioLab.thump(samples, 0.0, 0.22, 0.5)
	AudioLab.noise_burst(samples, 0.0, 0.1, 0.15, 3)
	AudioLab.tone(samples, 0.08, AudioLab.NOTE_E4, 0.12, 0.2)
	AudioLab.tone(samples, 0.16, AudioLab.NOTE_A4, 0.18, 0.2)
	return AudioLab.to_stream(AudioLab.normalize(samples, 0.75))


static func _demolish() -> AudioStreamWAV:
	var samples: PackedFloat32Array = AudioLab.silence(0.4)
	AudioLab.noise_burst(samples, 0.0, 0.3, 0.4, 11)
	AudioLab.thump(samples, 0.02, 0.25, 0.3)
	return AudioLab.to_stream(AudioLab.normalize(samples, 0.7))


static func _drone() -> AudioStreamWAV:
	# Короткий двойной сигнал: дрон взял задание.
	var samples: PackedFloat32Array = AudioLab.silence(0.22)
	AudioLab.tone(samples, 0.0, AudioLab.NOTE_G4, 0.07, 0.18, 0.003)
	AudioLab.tone(samples, 0.09, AudioLab.NOTE_C4 * 2.0, 0.09, 0.16, 0.003)
	return AudioLab.to_stream(AudioLab.normalize(samples, 0.45))


static func _furnace() -> AudioStreamWAV:
	# Мягкий выдох печи: шум с низким тоном, без металлического звона.
	var samples: PackedFloat32Array = AudioLab.silence(0.5)
	AudioLab.noise_burst(samples, 0.0, 0.45, 0.25, 23)
	AudioLab.tone(samples, 0.0, AudioLab.NOTE_A2, 0.4, 0.15, 0.05)
	return AudioLab.to_stream(AudioLab.normalize(samples, 0.5))


static func _research() -> AudioStreamWAV:
	var samples: PackedFloat32Array = AudioLab.silence(0.7)
	AudioLab.tone(samples, 0.0, AudioLab.NOTE_C4, 0.2, 0.22)
	AudioLab.tone(samples, 0.12, AudioLab.NOTE_E4, 0.2, 0.22)
	AudioLab.tone(samples, 0.24, AudioLab.NOTE_G4, 0.35, 0.24)
	return AudioLab.to_stream(AudioLab.normalize(samples, 0.7))


static func _achievement() -> AudioStreamWAV:
	var samples: PackedFloat32Array = AudioLab.silence(0.8)
	AudioLab.tone(samples, 0.0, AudioLab.NOTE_A3, 0.18, 0.2)
	AudioLab.tone(samples, 0.14, AudioLab.NOTE_C4, 0.18, 0.2)
	AudioLab.tone(samples, 0.28, AudioLab.NOTE_E4, 0.18, 0.2)
	AudioLab.tone(samples, 0.42, AudioLab.NOTE_A4, 0.35, 0.24)
	return AudioLab.to_stream(AudioLab.normalize(samples, 0.75))


static func _meteor() -> AudioStreamWAV:
	# Долгий шорох входа в атмосферу и удар.
	var samples: PackedFloat32Array = AudioLab.silence(1.4)
	AudioLab.noise_burst(samples, 0.0, 0.9, 0.35, 41)
	AudioLab.thump(samples, 0.85, 0.5, 0.6)
	return AudioLab.to_stream(AudioLab.normalize(samples, 0.85))


static func _victory() -> AudioStreamWAV:
	var samples: PackedFloat32Array = AudioLab.silence(2.2)
	var melody: Array[float] = [
		AudioLab.NOTE_A3, AudioLab.NOTE_C4, AudioLab.NOTE_E4,
		AudioLab.NOTE_A4, AudioLab.NOTE_G4, AudioLab.NOTE_E4, AudioLab.NOTE_A4,
	]
	for i: int in melody.size():
		AudioLab.tone(samples, float(i) * 0.22, melody[i], 0.5, 0.22)
	return AudioLab.to_stream(AudioLab.normalize(samples, 0.8))


static func _denied() -> AudioStreamWAV:
	var samples: PackedFloat32Array = AudioLab.silence(0.25)
	AudioLab.tone(samples, 0.0, AudioLab.NOTE_A2 * 1.3, 0.2, 0.25, 0.004)
	return AudioLab.to_stream(AudioLab.normalize(samples, 0.45))


## --- Музыка ----------------------------------------------------------------

## Спокойная петля: четыре аккорда минорной последовательности, мягкий бас,
## редкий «тук» и лёгкий шум винила. Ничего быстрого и мелодически навязчивого:
## под такую игру музыка должна работать фоном часами.
static func _lofi_loop() -> AudioStreamWAV:
	var bar_seconds: float = 4.0
	var bars: int = 4
	var samples: PackedFloat32Array = AudioLab.silence(bar_seconds * float(bars))

	# Am - F - C - G, по три ноты на аккорд.
	var chords: Array[Array] = [
		[AudioLab.NOTE_A2, AudioLab.NOTE_C3, AudioLab.NOTE_E3],
		[AudioLab.NOTE_F3, AudioLab.NOTE_A3, AudioLab.NOTE_C4],
		[AudioLab.NOTE_C3, AudioLab.NOTE_E3, AudioLab.NOTE_G3],
		[AudioLab.NOTE_G3, AudioLab.NOTE_A3 * 1.5, AudioLab.NOTE_E4],
	]

	for bar: int in bars:
		var start: float = float(bar) * bar_seconds
		var chord: Array = chords[bar % chords.size()]
		for note: float in chord:
			AudioLab.tone(samples, start, note, bar_seconds * 0.95, 0.13, 0.35)
		# Бас на первую и третью долю.
		AudioLab.tone(samples, start, chord[0] * 0.5, 1.2, 0.18, 0.05)
		AudioLab.tone(samples, start + 2.0, chord[0] * 0.5, 1.0, 0.14, 0.05)
		# Мягкий удар на каждую долю, кроме первой: даёт пульс, не отвлекая.
		for beat: int in 4:
			if beat != 0:
				AudioLab.noise_burst(samples, start + float(beat), 0.08, 0.05, bar * 10 + beat)

	# Шум винила поверх всего: он и склеивает петлю, и прячет стык.
	var rng: RandomNumberGenerator = Rng.stream(777)
	for i: int in samples.size():
		samples[i] += rng.randf_range(-1.0, 1.0) * 0.012

	return AudioLab.to_stream(AudioLab.normalize(samples, 0.55), true)
