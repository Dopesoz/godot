extends TestCase
## Интерфейс должен помещаться в экран телефона.
##
## Тест собирает игру целиком и проверяет главное свойство мобильной вёрстки:
## ничто не требует больше ширины, чем есть у экрана. Проверяется минимальный
## размер, а не нарисованный прямоугольник, и это принципиально: Control в Godot
## не может стать уже своего минимума, поэтому именно раздутый минимум — причина
## растянутых панелей, а не ошибка в якорях. Одна подпись без переносов внутри
## листа раздвигала всё меню за правый край экрана.

const PHONE_SIZES: Array[Vector2i] = [
	Vector2i(720, 1280),   # база
	Vector2i(1080, 2400),  # обычный современный телефон
	Vector2i(1440, 3120),  # QHD
	Vector2i(600, 1024),   # маленький бюджетный экран
]

## Сколько ширины съедают поля панели и безопасная зона.
const CHROME_WIDTH: int = 64

var main: Node = null
var _original_size: Vector2i = Vector2i.ZERO


func before_each() -> void:
	_original_size = Engine.get_main_loop().root.size
	SaveSystem.delete_save()
	main = load("res://scenes/main.tscn").instantiate()
	Engine.get_main_loop().root.add_child(main)


func after_each() -> void:
	Engine.get_main_loop().root.size = _original_size
	if is_instance_valid(main):
		main.free()
	main = null
	SaveSystem.delete_save()


func viewport_size() -> Vector2:
	return Engine.get_main_loop().root.get_visible_rect().size


func panels() -> Array[UiPanel]:
	return [
		main.build_menu, main.info_panel, main.research_panel,
		main.settings_panel, main.achievements_panel, main.story_panel,
	] as Array[UiPanel]


## Все панели с наполнением: у пустой панели нечему быть слишком широким.
func open_everything() -> void:
	# Панель здания без выбранного здания сама закрывается — даём ей склад.
	main.info_panel._building_id = main.world.buildings.all()[0].id
	for panel: UiPanel in panels():
		panel.open()
		if panel.has_method("refresh"):
			panel.call("refresh")


func walk(node: Node, out: Array[Control]) -> Array[Control]:
	for child: Node in node.get_children():
		if child is Control:
			out.append(child)
		walk(child, out)
	return out


func widest(root: Node) -> Array:
	var worst: float = 0.0
	var worst_node: Control = null
	for control: Control in walk(root, [] as Array[Control]):
		var width: float = control.get_combined_minimum_size().x
		if width > worst:
			worst = width
			worst_node = control
	return [worst, worst_node]


func test_always_visible_ui_fits_the_screen() -> void:
	# HUD и панель подтверждения живут поверх карты и не прокручиваются:
	# им вылезать за экран нельзя вообще никогда.
	main.build_controller.start_building(BuildingDefs.DRONE_PORT)
	for size: Vector2i in PHONE_SIZES:
		Engine.get_main_loop().root.size = size
		main.hud.show_toast("Дроны развезли всё, что нашли на разобранном обломке")
		main.hud.refresh_objective()
		var budget: float = viewport_size().x - float(CHROME_WIDTH)
		for layer: CanvasLayer in [main.hud, main.build_bar] as Array[CanvasLayer]:
			var found: Array = widest(layer)
			check(
				float(found[0]) <= budget,
				"на экране %s элемент %s/%s требует %.0f при бюджете %.0f" % [
					size, layer.name,
					"?" if found[1] == null else layer.get_path_to(found[1]),
					float(found[0]), budget,
				]
			)


func test_panels_fit_the_screen() -> void:
	for size: Vector2i in PHONE_SIZES:
		Engine.get_main_loop().root.size = size
		open_everything()
		var budget: float = viewport_size().x - float(CHROME_WIDTH)
		for panel: UiPanel in panels():
			var found: Array = widest(panel)
			check(
				float(found[0]) <= budget,
				"на экране %s в %s элемент %s требует %.0f при бюджете %.0f" % [
					size, panel.name,
					"?" if found[1] == null else panel.get_path_to(found[1]),
					float(found[0]), budget,
				]
			)


## Главная страховка: даже если наполнение когда-нибудь окажется слишком
## широким, сам лист обязан остаться в границах экрана.
func test_sheet_never_exceeds_screen_even_with_absurd_content() -> void:
	var panel: SettingsPanel = main.settings_panel
	panel.open()
	var bomb: Label = UiWidgets.label("СЛИШКОМ ДЛИННАЯ СТРОКА ".repeat(40))
	panel.content().add_child(bomb)

	for size: Vector2i in PHONE_SIZES:
		Engine.get_main_loop().root.size = size
		var width: float = viewport_size().x
		check(
			panel._holder.get_combined_minimum_size().x <= width,
			"лист требует %.0f при экране %.0f (%s)" % [
				panel._holder.get_combined_minimum_size().x, width, size,
			]
		)


func test_roots_follow_window_resize() -> void:
	# Именно это ломалось на устройстве: окно получает настоящий размер после
	# старта, а интерфейс оставался с прежними габаритами и уезжал за край.
	for size: Vector2i in PHONE_SIZES:
		Engine.get_main_loop().root.size = size
		check_eq(hud_root().size, viewport_size(), "HUD не подстроился под %s" % size)
		for panel: UiPanel in panels():
			check_eq(
				(panel.get_child(0) as Control).size, viewport_size(),
				"%s не подстроилась под %s" % [panel.name, size]
			)


func hud_root() -> Control:
	return main.hud.get_node("Root") as Control


func test_panel_content_is_limited_in_width() -> void:
	# На широком экране кнопки не должны растягиваться через всю ширину.
	Engine.get_main_loop().root.size = Vector2i(2400, 1800)
	main.settings_panel.open()
	var holder: MarginContainer = main.settings_panel._holder
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
		main.settings_panel.open()
		var margins: Vector4i = UiTheme.safe_area_margins()
		check_eq(
			main.settings_panel._holder.get_theme_constant("margin_left"), margins.x,
			"на экране %s лишних отступов быть не должно (видимая ширина %.0f)" % [
				size, viewport_size().x,
			]
		)
