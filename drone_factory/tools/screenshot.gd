extends SceneTree
## Снимки настоящего интерфейса в PNG.
##
## Тесты проверяют раскладку числами, но «панель уехала за край» игрок видит
## глазами, и дважды именно так и находил ошибку. Этот инструмент открывает
## каждую панель на телефонном разрешении и сохраняет то, что нарисовалось.
##
## Запуск (нужен любой экран, в том числе виртуальный):
##   xvfb-run -a godot --path drone_factory --script res://tools/screenshot.gd
##
## Файлы кладутся в res://shot_<имя>.png и в репозиторий не попадают.

## Через сколько кадров после открытия панели делать снимок: раскладка
## контейнеров пересчитывается отложенно.
const SETTLE_FRAMES: int = 4
## Сколько кадров дать игре на запуск: генерация мира и сборка атласов.
const WARMUP_FRAMES: int = 20

const SHOTS: Array[String] = ["settings", "build", "research", "story", "info"]

var _frames: int = 0
var _main: Node = null
var _index: int = 0


func _initialize() -> void:
	root.size = Vector2i(1080, 2400)
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < WARMUP_FRAMES:
		return false
	if _index >= SHOTS.size():
		return true
	if _frames == WARMUP_FRAMES:
		_open(SHOTS[_index])
		return false
	if _frames < WARMUP_FRAMES + SETTLE_FRAMES:
		return false

	var image: Image = root.get_texture().get_image()
	image.save_png("res://shot_%s.png" % SHOTS[_index])
	print("сохранён shot_%s.png" % SHOTS[_index])
	_index += 1
	_frames = WARMUP_FRAMES - 1
	return false


func _open(name: String) -> void:
	for panel: Node in [
		_main.settings_panel, _main.build_menu, _main.research_panel,
		_main.story_panel, _main.info_panel,
	]:
		panel.call("close")
	match name:
		"settings":
			_main.settings_panel.open()
		"build":
			_main.build_menu.open()
		"research":
			_main.research_panel.open()
		"story":
			_main.story_panel.open()
		"info":
			_main.build_controller.select(_main.world.buildings.all()[0].id)
