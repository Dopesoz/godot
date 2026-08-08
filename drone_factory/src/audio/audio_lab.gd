class_name AudioLab
extends RefCounted

## Процедурный синтез звука.
##
## Как и графика, весь звук считается кодом при старте: в проекте нет ни одного
## аудиофайла. Это держит APK маленьким, а тембры — согласованными между собой.
##
## Формат — 16-битный моно PCM на 22050 Гц. Для мягкого lo-fi этого более чем
## достаточно, а память и время генерации остаются в разумных пределах.

const RATE: int = 22050
## Частота для музыки. Фоновая петля состоит из мягких низких тонов и шороха —
## выше пяти килогерц в ней ничего нет, и вдвое меньшая частота слышится так
## же. Зато синтез считается вдвое быстрее, а на слабом телефоне время старта
## — это то, что игрок замечает первым.
const MUSIC_RATE: int = 11025

## Ноты в герцах: минорная гамма, на которой строятся и музыка, и сигналы.
const NOTE_A2: float = 110.0
const NOTE_C3: float = 130.81
const NOTE_E3: float = 164.81
const NOTE_F3: float = 174.61
const NOTE_G3: float = 196.0
const NOTE_A3: float = 220.0
const NOTE_C4: float = 261.63
const NOTE_E4: float = 329.63
const NOTE_G4: float = 392.0
const NOTE_A4: float = 440.0


## Собирает поток из массива сэмплов -1..1.
static func to_stream(
	samples: PackedFloat32Array, loop: bool = false, rate: int = RATE
) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i: int in samples.size():
		var value: int = int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, value)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = samples.size()
	return stream


static func silence(seconds: float, rate: int = RATE) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(int(seconds * rate))
	return samples


## Мягкая нота: синус с небольшой примесью третьей гармоники и плавным
## затуханием. Резкая прямоугольная волна на телефонном динамике звучит
## как писк, поэтому её здесь нет.
static func tone(
	samples: PackedFloat32Array,
	start_seconds: float,
	frequency: float,
	duration: float,
	volume: float = 0.3,
	attack: float = 0.01,
	rate: int = RATE
) -> void:
	var start: int = int(start_seconds * rate)
	var length: int = int(duration * rate)
	for i: int in length:
		var index: int = start + i
		if index < 0 or index >= samples.size():
			continue
		var t: float = float(i) / float(rate)
		var progress: float = float(i) / float(length)
		# Огибающая: короткая атака, длинный экспоненциальный спад.
		var envelope: float = minf(t / maxf(attack, 0.001), 1.0) * pow(1.0 - progress, 1.6)
		var wave: float = sin(TAU * frequency * t) + 0.25 * sin(TAU * frequency * 3.0 * t)
		samples[index] += wave * envelope * volume * 0.8


## Шумовой удар: основа для «тука» и шороха.
static func noise_burst(
	samples: PackedFloat32Array,
	start_seconds: float,
	duration: float,
	volume: float = 0.2,
	seed_value: int = 1,
	rate: int = RATE
) -> void:
	var start: int = int(start_seconds * rate)
	var length: int = int(duration * rate)
	var rng: RandomNumberGenerator = Rng.stream(seed_value)
	var previous: float = 0.0
	for i: int in length:
		var index: int = start + i
		if index < 0 or index >= samples.size():
			continue
		var progress: float = float(i) / float(length)
		# Фильтр нижних частот: белый шум на телефоне звучит как помеха.
		previous = lerpf(previous, rng.randf_range(-1.0, 1.0), 0.35)
		samples[index] += previous * pow(1.0 - progress, 2.0) * volume


## Низкий удар с падающей высотой — «бум» для постройки и метеорита.
static func thump(
	samples: PackedFloat32Array, start_seconds: float, duration: float, volume: float = 0.35
) -> void:
	var start: int = int(start_seconds * RATE)
	var length: int = int(duration * RATE)
	for i: int in length:
		var index: int = start + i
		if index < 0 or index >= samples.size():
			continue
		var progress: float = float(i) / float(length)
		var frequency: float = lerpf(160.0, 55.0, progress)
		var t: float = float(i) / float(RATE)
		samples[index] += sin(TAU * frequency * t) * pow(1.0 - progress, 2.5) * volume


## Нормализация к заданному пику: разные эффекты не должны отличаться по
## громкости в разы.
static func normalize(samples: PackedFloat32Array, peak: float = 0.8) -> PackedFloat32Array:
	var maximum: float = 0.0
	for value: float in samples:
		maximum = maxf(maximum, absf(value))
	if maximum < 0.0001:
		return samples
	var gain: float = peak / maximum
	for i: int in samples.size():
		samples[i] *= gain
	return samples
