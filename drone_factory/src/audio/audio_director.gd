class_name AudioDirector
extends Node

## Звуковое сопровождение: музыка, эффекты и фоновый гул фабрики.
##
## Подписывается на те же события, что и интерфейс, поэтому игровые системы
## о звуке ничего не знают. Отдельно решается главная мобильная проблема:
## сотня печей не должна давать сотню звуков. Вместо этого работающие машины
## складываются в один негромкий гул, громкость которого растёт с размером
## фабрики, а разовые эффекты ограничены по частоте.

## Сколько одновременных эффектов допускаем.
const VOICES: int = 5
## Не чаще одного одинакового эффекта в этот интервал, секунды.
const EFFECT_COOLDOWN: float = 0.12
## Как быстро подстраивается громкость гула.
const HUM_SMOOTHING: float = 1.5
## Сколько раз петля проигрывается подряд, прежде чем включится следующий трек.
##
## Не один: смена на каждом круге читается как дёрганый плейлист. Не десять:
## тогда возвращается та самая «заедающая» петля, ради которой треки и
## разводились. Три круга — это примерно минута на трек.
const LOOPS_PER_TRACK: int = 3

var music_volume: float = 0.6
var sfx_volume: float = 0.8

var _music_player: AudioStreamPlayer = null
var _track_index: int = 0
var _track_time: float = 0.0
var _hum_player: AudioStreamPlayer = null
var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _last_played: Dictionary[StringName, float] = {}
var _time: float = 0.0
var _hum_target: float = 0.0
var _hum_level: float = 0.0

var _registry: BuildingRegistry = null


func _ready() -> void:
	SoundBank.build()

	_music_player = AudioStreamPlayer.new()
	# Трек стартует со случайного места списка: иначе каждая партия начинается
	# с одной и той же мелодии, и это первое, что приедается.
	_track_index = randi() % maxi(SoundBank.track_count(), 1)
	_music_player.stream = SoundBank.music(_track_index)
	_music_player.bus = &"Master"
	add_child(_music_player)

	# Гул — та же петля печи, растянутая тихим фоном.
	_hum_player = AudioStreamPlayer.new()
	_hum_player.stream = SoundBank.effect(SoundBank.FURNACE)
	add_child(_hum_player)

	for i: int in VOICES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_voices.append(player)

	Events.building_placed.connect(_on_building_placed)
	Events.building_removed.connect(func(_id: int) -> void: play(SoundBank.DEMOLISH))
	Events.research_completed.connect(func(_id: StringName) -> void: play(SoundBank.RESEARCH))
	Events.achievement_unlocked.connect(func(_id: StringName) -> void: play(SoundBank.ACHIEVEMENT))
	Events.game_won.connect(func() -> void: play(SoundBank.VICTORY))
	Events.drone_count_changed.connect(_on_drones_changed)

	apply_volumes()


func setup(building_registry: BuildingRegistry) -> void:
	_registry = building_registry


## --- Громкость -------------------------------------------------------------

func apply_volumes() -> void:
	if _music_player == null:
		return
	_music_player.volume_db = _to_db(music_volume)
	if music_volume > 0.001 and not _music_player.playing:
		_music_player.play()
	elif music_volume <= 0.001 and _music_player.playing:
		_music_player.stop()


## Смена трека.
##
## Петли зациклены самим потоком (так между кругами нет щелчка), поэтому
## сигнала об окончании не будет — время считаем сами и переключаемся ровно
## на границе круга, чтобы мелодия не обрывалась на полуфразе.
func _update_music(delta: float) -> void:
	if _music_player == null or not _music_player.playing:
		return
	var length: float = _music_player.stream.get_length()
	if length <= 0.0:
		return
	_track_time += delta
	if _track_time < length * float(LOOPS_PER_TRACK):
		return
	_track_time = 0.0
	next_track()


## Переключает музыку на следующий трек по кругу.
func next_track() -> void:
	if SoundBank.track_count() <= 1:
		return
	_track_index = (_track_index + 1) % SoundBank.track_count()
	_music_player.stream = SoundBank.music(_track_index)
	_track_time = 0.0
	if music_volume > 0.001:
		_music_player.play()


## Какой трек звучит сейчас — для интерфейса и тестов.
func current_track() -> int:
	return _track_index


static func _to_db(volume: float) -> float:
	# Линейная громкость воспринимается неровно, поэтому переводим в децибелы.
	return -80.0 if volume <= 0.001 else linear_to_db(clampf(volume, 0.0, 1.0))


## --- Воспроизведение -------------------------------------------------------

func play(effect_id: StringName) -> void:
	if sfx_volume <= 0.001:
		return
	# Один и тот же эффект не должен звучать десять раз подряд: при массовой
	# постройке это превращается в треск.
	if _time - _last_played.get(effect_id, -999.0) < EFFECT_COOLDOWN:
		return
	_last_played[effect_id] = _time

	var player: AudioStreamPlayer = _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	player.stream = SoundBank.effect(effect_id)
	player.volume_db = _to_db(sfx_volume)
	player.play()


func _process(delta: float) -> void:
	_time += delta
	_update_music(delta)
	_update_hum(delta)


## Гул фабрики: громкость зависит от числа работающих машин, но растёт
## логарифмически — сто печей не должны быть в десять раз громче десяти.
func _update_hum(delta: float) -> void:
	if _registry == null or _hum_player == null:
		return
	var working: int = 0
	for kind: int in [
		BuildingDefs.Kind.FURNACE, BuildingDefs.Kind.ASSEMBLER,
		BuildingDefs.Kind.DRILL, BuildingDefs.Kind.BOILER,
	]:
		for building: Building in _registry.of_kind(kind):
			if building.status == Building.Status.WORKING:
				working += 1

	_hum_target = 0.0 if working == 0 else clampf(log(float(working) + 1.0) / 5.0, 0.05, 0.5)
	_hum_level = lerpf(_hum_level, _hum_target, clampf(HUM_SMOOTHING * delta, 0.0, 1.0))

	var level: float = _hum_level * sfx_volume
	if level <= 0.01:
		if _hum_player.playing:
			_hum_player.stop()
		return
	_hum_player.volume_db = _to_db(level)
	if not _hum_player.playing:
		_hum_player.play()


func _on_building_placed(building_id: int) -> void:
	if _registry == null:
		play(SoundBank.BUILD)
		return
	var building: Building = _registry.get_building(building_id)
	# Метеорит «строится» той же системой, но звучать должен иначе.
	if building != null and BuildingDefs.kind(building.def_id) == BuildingDefs.Kind.WRECK:
		play(SoundBank.METEOR)
	else:
		play(SoundBank.BUILD)


func _on_drones_changed(active: int, _total: int) -> void:
	if active > 0:
		play(SoundBank.DRONE)
