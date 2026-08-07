extends Node
## Корневой узел игры: собирает мир, системы и интерфейс.

## Пока камеры нет, показываем фиксированное окно вокруг старта.
const BOOTSTRAP_VIEW_SIZE := Vector2(720, 1280)

var world: GameWorld = null


func _ready() -> void:
	Log.info("Drone Factory %s, движок %s" % [
		ProjectSettings.get_setting("application/config/version", "?"),
		Engine.get_version_info().string,
	])

	world = GameWorld.new()
	world.name = "World"
	add_child(world)

	var seed_value: int = int(Time.get_unix_time_from_system())
	var start: Vector2i = world.new_game(seed_value)

	var center: Vector2 = Grid.cell_to_world_center(start)
	world.update_view(Rect2(center - BOOTSTRAP_VIEW_SIZE * 0.5, BOOTSTRAP_VIEW_SIZE))
	world.terrain_renderer.flush_pending()

	Log.info("Мир готов: старт %s, загружено чанков %d" % [
		start, world.terrain_renderer.loaded_chunk_count(),
	])
