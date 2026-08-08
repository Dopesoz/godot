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
static var _tracks: Array[AudioStreamWAV] = []
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
	_tracks.clear()
	for index: int in TRACKS.size():
		_tracks.append(_lofi_loop(index))

	_built = true
	var seconds: float = 0.0
	for track: AudioStreamWAV in _tracks:
		seconds += float(track.data.size() / 2) / float(AudioLab.MUSIC_RATE)
	Log.info("Звук: %d эффектов и %d трека(ов) на %.0f с за %.0f мс" % [
		_effects.size(), _tracks.size(), seconds,
		float(Time.get_ticks_usec() - start_usec) / 1000.0,
	])


## Сброс собранного банка. Нужен тестам, которые меряют время сборки.
static func reset() -> void:
	_effects.clear()
	_tracks.clear()
	_built = false


static func effect(id: StringName) -> AudioStreamWAV:
	build()
	return _effects.get(id)


## Один из фоновых треков. Индекс закольцован, поэтому вызывающему не нужно
## помнить, сколько их всего.
static func music(index: int = 0) -> AudioStreamWAV:
	build()
	return _tracks[posmod(index, _tracks.size())]


static func track_count() -> int:
	build()
	return _tracks.size()


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

## Описания фоновых треков.
##
## Одной петли на всю игру мало: партия идёт часами, и шестнадцать секунд по
## кругу начинают раздражать раньше, чем игрок доберётся до электроники.
## Треки отличаются не только аккордами, но и темпом, плотностью баса и
## наличием пульса — иначе разница на слух не читается и получается одна и та
## же петля в четырёх видах.
##
## Поля: chords — последовательность аккордов (частоты нот);
##       bar — длительность такта в секундах;
##       beats — сколько мягких ударов в такте (0 — без пульса);
##       bass — громкость баса; hiss — уровень «винила».
const TRACKS: Array[Dictionary] = [
	{
		"name": "Пыль", "bar": 4.0, "beats": 4, "bass": 0.18, "hiss": 0.012, "seed": 777,
		"chords": [[0, 3, 7], [-4, 0, 3], [-9, -5, -2], [-2, 1, 5]], "root": 110.0,
	},
	{
		"name": "Дальний свет", "bar": 5.0, "beats": 0, "bass": 0.12, "hiss": 0.018, "seed": 1451,
		"chords": [[0, 4, 7], [2, 5, 9], [-3, 0, 4], [-5, -1, 2]], "root": 98.0,
	},
	{
		"name": "Ночная смена", "bar": 3.5, "beats": 2, "bass": 0.22, "hiss": 0.010, "seed": 2237,
		"chords": [[0, 3, 10], [-2, 3, 7], [-5, -1, 2], [-7, -3, 0]], "root": 116.5,
	},
	{
		"name": "Тёплый металл", "bar": 4.5, "beats": 3, "bass": 0.15, "hiss": 0.015, "seed": 3313,
		"chords": [[0, 5, 9], [-3, 2, 7], [-1, 4, 8], [-6, -1, 3]], "root": 103.8,
	},
]


## Полутон в равномерном строе: частота ноты = основание * 2^(шаг/12).
static func _semitone(root: float, step: int) -> float:
	return root * pow(2.0, float(step) / 12.0)


## Спокойная петля: аккордовая последовательность, мягкий бас, редкий «тук»
## и лёгкий шум винила. Ничего быстрого и мелодически навязчивого: под такую
## игру музыка должна работать фоном часами.
static func _lofi_loop(index: int) -> AudioStreamWAV:
	var track: Dictionary = TRACKS[posmod(index, TRACKS.size())]
	var bar_seconds: float = float(track["bar"])
	var chord_steps: Array = track["chords"]
	var root: float = float(track["root"])
	var bars: int = chord_steps.size()
	var samples: PackedFloat32Array = AudioLab.silence(bar_seconds * float(bars), AudioLab.MUSIC_RATE)

	for bar: int in bars:
		var start: float = float(bar) * bar_seconds
		var steps: Array = chord_steps[bar]
		var bass_note: float = _semitone(root, int(steps[0]))
		for step: Variant in steps:
			AudioLab.tone(
				samples, start, _semitone(root, int(step)), bar_seconds * 0.95,
				0.13, 0.35, AudioLab.MUSIC_RATE
			)
		# Бас на первую и третью долю.
		AudioLab.tone(
			samples, start, bass_note * 0.5, bar_seconds * 0.3,
			float(track["bass"]), 0.05, AudioLab.MUSIC_RATE
		)
		AudioLab.tone(
			samples, start + bar_seconds * 0.5, bass_note * 0.5,
			bar_seconds * 0.25, float(track["bass"]) * 0.8, 0.05, AudioLab.MUSIC_RATE
		)
		# Мягкий удар по долям, кроме первой: даёт пульс, не отвлекая.
		var beats: int = int(track["beats"])
		for beat: int in beats:
			if beat != 0:
				AudioLab.noise_burst(
					samples, start + bar_seconds * float(beat) / float(beats),
					0.08, 0.05, bar * 10 + beat + index * 100, AudioLab.MUSIC_RATE
				)

	# Шум винила поверх всего: он и склеивает петлю, и прячет стык.
	var rng: RandomNumberGenerator = Rng.stream(int(track["seed"]))
	var hiss: float = float(track["hiss"])
	for i: int in samples.size():
		samples[i] += rng.randf_range(-1.0, 1.0) * hiss

	return AudioLab.to_stream(AudioLab.normalize(samples, 0.55), true, AudioLab.MUSIC_RATE)
