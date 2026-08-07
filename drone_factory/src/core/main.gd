extends Node
## Корневой узел игры: собирает мир, камеру, системы и интерфейс.

var world: GameWorld = null
var camera: GameCamera = null
var touch: TouchInput = null


func _ready() -> void:
	Log.info("Drone Factory %s, движок %s" % [
		ProjectSettings.get_setting("application/config/version", "?"),
		Engine.get_version_info().string,
	])

	world = GameWorld.new()
	world.name = "World"
	add_child(world)

	camera = GameCamera.new()
	camera.name = "Camera"
	world.add_child(camera)

	touch = TouchInput.new()
	touch.name = "TouchInput"
	touch.camera = camera
	add_child(touch)
	touch.tapped.connect(_on_tapped)
	touch.long_pressed.connect(_on_long_pressed)

	var seed_value: int = int(Time.get_unix_time_from_system())
	var start: Vector2i = world.new_game(seed_value)

	camera.focus_on_cell(start)
	world.update_view(camera.visible_world_rect())
	world.terrain_renderer.flush_pending()

	Log.info("Мир готов: старт %s, загружено чанков %d" % [
		start, world.terrain_renderer.loaded_chunk_count(),
	])


func _process(_delta: float) -> void:
	# Стриминг чанков идёт за камерой. Сам вызов дешёвый: если набор видимых
	# чанков не изменился, рендер выходит сразу.
	world.update_view(camera.visible_world_rect())


func _on_tapped(screen_position: Vector2) -> void:
	var cell: Vector2i = camera.screen_to_cell(screen_position)
	Log.debug("Тап по клетке %s: %s / %s" % [
		cell,
		TileTypes.terrain_name(world.grid.get_terrain(cell)),
		TileTypes.ore_name(world.grid.get_ore(cell)),
	])


func _on_long_pressed(screen_position: Vector2) -> void:
	Log.debug("Долгое нажатие на клетке %s" % camera.screen_to_cell(screen_position))
