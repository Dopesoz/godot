extends TestCase
## Интерфейс должен подстраиваться под настоящий размер экрана.
##
## На Android окно получает реальные габариты уже после старта, поэтому
## проверяем не только начальное состояние, но и поведение при изменении
## размера вьюпорта.

const PHONE_SIZES: Array[Vector2i] = [
	Vector2i(720, 1280),   # база
	Vector2i(1080, 2400),  # обычный современный телефон
	Vector2i(1440, 3120),  # QHD
	Vector2i(600, 1024),   # маленький бюджетный экран
]

var world: GameWorld = null
var simulation: Simulation = null
var hud: Hud = null
var panel: SettingsPanel = null
var _original_size: Vector2i = Vector2i.ZERO


func before_each() -> void:
	_original_size = Engine.get_main_loop().root.size

	world = GameWorld.new()
	Engine.get_main_loop().root.add_child(world)
	simulation = Simulation.new()
	Engine.get_main_loop().root.add_child(simulation)
	world.simulation = simulation
	simulation.add_system(StorySystem.new())
	world.new_game(313)
	simulation.setup(world)

	hud = Hud.new()
	Engine.get_main_loop().root.add_child(hud)
	hud.setup(world, simulation)

	panel = SettingsPanel.new()
	Engine.get_main_loop().root.add_child(panel)


func after_each() -> void:
	Engine.get_main_loop().root.size = _original_size
	for node: Node in [panel, hud, simulation, world]:
		if is_instance_valid(node):
			node.free()
	world = null
	simulation = null
	hud = null
	panel = null


func viewport_size() -> Vector2:
	return Engine.get_main_loop().root.get_visible_rect().size


func hud_root() -> Control:
	return hud.get_node("Root") as Control


func panel_root() -> Control:
	return panel.get_child(0) as Control


func test_roots_match_viewport_on_start() -> void:
	check_eq(hud_root().size, viewport_size(), "корень HUD должен занимать весь экран")
	check_eq(panel_root().size, viewport_size(), "корень панели должен занимать весь экран")


func test_roots_follow_window_resize() -> void:
	# Именно это ломалось на устройстве: окно получает настоящий размер после
	# старта, а интерфейс оставался с прежними габаритами и уезжал за край.
	for size: Vector2i in PHONE_SIZES:
		Engine.get_main_loop().root.size = size
		check_eq(hud_root().size, viewport_size(), "HUD не подстроился под %s" % size)
		check_eq(panel_root().size, viewport_size(), "панель не подстроилась под %s" % size)


func test_ui_never_extends_beyond_screen() -> void:
	for size: Vector2i in PHONE_SIZES:
		Engine.get_main_loop().root.size = size
		var width: float = viewport_size().x
		check(hud_root().size.x <= width + 0.5, "HUD шире экрана при %s" % size)
		check(panel_root().size.x <= width + 0.5, "панель шире экрана при %s" % size)


func test_panel_content_is_limited_in_width() -> void:
	# На широком экране кнопки не должны растягиваться через всю ширину.
	# Считаем в единицах вьюпорта, а не в пикселях окна: при растяжении
	# «expand» это разные величины.
	Engine.get_main_loop().root.size = Vector2i(2400, 1800)
	panel.open()
	var holder: MarginContainer = panel._holder
	var left: int = holder.get_theme_constant("margin_left")
	var right: int = holder.get_theme_constant("margin_right")
	var content_width: float = viewport_size().x - float(left + right)
	check(viewport_size().x > UiWidgets.MAX_CONTENT_WIDTH, "экран должен быть широким для проверки")
	check(
		content_width <= float(UiWidgets.MAX_CONTENT_WIDTH) + 1.0,
		"содержимое панели %.0f при пределе %d" % [content_width, UiWidgets.MAX_CONTENT_WIDTH]
	)


func test_phone_screen_keeps_full_width() -> void:
	# На телефоне панель обязана занимать всю доступную ширину: предел нужен
	# только планшетам.
	for size: Vector2i in [Vector2i(720, 1280), Vector2i(1080, 2400), Vector2i(600, 1024)]:
		Engine.get_main_loop().root.size = size
		panel.open()
		var margins: Vector4i = UiTheme.safe_area_margins()
		check_eq(
			panel._holder.get_theme_constant("margin_left"), margins.x,
			"на экране %s лишних отступов быть не должно (видимая ширина %.0f)" % [
				size, viewport_size().x,
			]
		)
