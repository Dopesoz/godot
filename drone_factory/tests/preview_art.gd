extends SceneTree
## Выгрузка атласов в PNG для визуальной проверки пиксель-арта.
##
## Запуск:
##   godot --headless --path drone_factory --script res://tests/preview_art.gd
## Файлы появятся в user://, увеличенные в 4 раза (NEAREST — пиксели остаются
## пикселями).

const SCALE: int = 4

var done: bool = false
func _process(_d: float) -> bool:
	if done:
		return true
	done = true
	Art.build()
	var terrain := Art.terrain_texture.get_image()
	terrain.resize(terrain.get_width() * SCALE, terrain.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	terrain.save_png("user://terrain.png")
	var objects := Art.object_texture.get_image()
	objects.resize(objects.get_width() * SCALE, objects.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	objects.save_png("user://objects.png")
	print("saved to ", ProjectSettings.globalize_path("user://"))
	quit(0)
	return true
