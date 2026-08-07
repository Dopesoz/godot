class_name SaveSystem
extends Node

## Сохранение и загрузка игры.
##
## Формат — JSON с версией. Слои мира пакуются в сжатый бинарный блоб (см.
## Grid.serialize_layers): хранить четверть миллиона чисел текстом нельзя ни по
## размеру, ни по времени разбора на телефоне.
##
## Запись атомарная: сначала во временный файл, потом переименование. На
## Android процесс могут убить в любой момент, и половина файла на диске —
## это потерянная игра. Переименование в пределах одной файловой системы
## атомарно, поэтому старое сохранение цело до последнего момента.
##
## Мир не перегенерируется из сида при загрузке: разбор готового блоба быстрее
## генерации, а игрок ждёт загрузки, глядя в пустой экран.

## Автосохранение раз в столько секунд реального времени.
const AUTOSAVE_INTERVAL: float = 120.0

var world: GameWorld = null
var simulation: Simulation = null
var camera: GameCamera = null
var research: ResearchSystem = null
var logistics: LogisticsSystem = null

## Автосохранение можно выключить в настройках.
var autosave_enabled: bool = true

var _autosave_timer: float = 0.0


func setup(
	game_world: GameWorld,
	game_simulation: Simulation,
	game_camera: GameCamera
) -> void:
	world = game_world
	simulation = game_simulation
	camera = game_camera
	research = simulation.get_system(ResearchSystem) as ResearchSystem
	logistics = simulation.get_system(LogisticsSystem) as LogisticsSystem


func _process(delta: float) -> void:
	if not autosave_enabled or world == null or world.grid == null:
		return
	_autosave_timer += delta
	if _autosave_timer < AUTOSAVE_INTERVAL:
		return
	_autosave_timer = 0.0
	save_game()


## --- Файлы -----------------------------------------------------------------

static func has_save() -> bool:
	return FileAccess.file_exists(Constants.SAVE_FILE)


static func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Constants.SAVE_FILE))


func save_game() -> bool:
	if world == null or world.grid == null:
		return false
	var start_usec: int = Time.get_ticks_usec()

	DirAccess.make_dir_recursive_absolute(Constants.SAVE_DIR)
	var temp_path: String = Constants.SAVE_FILE + ".tmp"
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		Log.error("Сохранение: не удалось открыть %s (%d)" % [temp_path, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(collect()))
	file.close()

	var directory: DirAccess = DirAccess.open(Constants.SAVE_DIR)
	if directory == null:
		Log.error("Сохранение: нет доступа к каталогу сохранений")
		return false
	if directory.rename(temp_path.get_file(), Constants.SAVE_FILE.get_file()) != OK:
		Log.error("Сохранение: не удалось заменить файл")
		return false

	Log.info("Игра сохранена за %.0f мс" % (float(Time.get_ticks_usec() - start_usec) / 1000.0))
	Events.game_saved.emit()
	Events.notify.emit("Игра сохранена")
	return true


func load_game() -> bool:
	if not has_save():
		return false
	var start_usec: int = Time.get_ticks_usec()

	var file: FileAccess = FileAccess.open(Constants.SAVE_FILE, FileAccess.READ)
	if file == null:
		Log.error("Загрузка: не удалось открыть файл сохранения")
		return false
	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		Log.error("Загрузка: файл сохранения повреждён")
		return false
	if not apply(parsed):
		return false

	Log.info("Игра загружена за %.0f мс" % (float(Time.get_ticks_usec() - start_usec) / 1000.0))
	Events.game_loaded.emit()
	Events.notify.emit("Игра загружена")
	return true


## --- Формат ----------------------------------------------------------------

## Собирает состояние игры в словарь. Вынесено отдельно от записи на диск,
## чтобы формат можно было проверять тестами без файловой системы.
func collect() -> Dictionary:
	return {
		"version": Constants.SAVE_FORMAT_VERSION,
		"seed": world.world_seed,
		"start": [world.start_cell.x, world.start_cell.y],
		"time": simulation.game_time,
		"tick": simulation.tick_count,
		"camera": {
			"x": camera.position.x,
			"y": camera.position.y,
			"zoom": camera.get_zoom_level(),
		},
		"grid": world.grid.serialize_layers(),
		"buildings": world.buildings.serialize(),
		"research_done": world.research.serialize(),
		"research_active": research.serialize() if research != null else {},
	}


## Восстанавливает состояние игры из словаря.
func apply(data: Dictionary) -> bool:
	var version: int = int(data.get("version", 0))
	if version != Constants.SAVE_FORMAT_VERSION:
		# Формат меняется редко; когда изменится, здесь появится миграция.
		Log.error("Загрузка: несовместимая версия сохранения (%d)" % version)
		Events.notify.emit("Сохранение от другой версии игры")
		return false

	world.prepare_for_load(int(data.get("seed", 0)))
	if not world.grid.deserialize_layers(data.get("grid", {})):
		return false

	var start: Array = data.get("start", [0, 0])
	world.start_cell = Vector2i(int(start[0]), int(start[1]))
	world.buildings.deserialize(data.get("buildings", []))
	world.research.deserialize(data.get("research_done", []))
	if research != null:
		research.deserialize(data.get("research_active", {}))

	simulation.reset()
	simulation.game_time = float(data.get("time", 0.0))
	simulation.tick_count = int(data.get("tick", 0))

	var camera_data: Dictionary = data.get("camera", {})
	camera.set_zoom_level(float(camera_data.get("zoom", Constants.CAMERA_ZOOM_DEFAULT)), false)
	camera.position = Vector2(
		float(camera_data.get("x", camera.position.x)),
		float(camera_data.get("y", camera.position.y))
	)

	# Дроны загружены уже в полёте: логистика обязана узнать об их грузах,
	# иначе брони разъедутся и ресурсы задвоятся.
	if logistics != null:
		logistics.rebuild_reservations(world.buildings)

	world.after_load(camera.visible_world_rect())
	return true


## Сохранение по требованию: уход в фон, выход из игры, кнопка в меню.
func save_on_exit() -> void:
	if world != null and world.grid != null:
		save_game()
