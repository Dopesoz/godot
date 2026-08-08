extends TestCase
## Меню строительства и панель подтверждения.

var world: GameWorld = null
var camera: GameCamera = null
var controller: BuildController = null
var menu: BuildMenu = null
var bar: BuildBar = null


func before_each() -> void:
	world = GameWorld.new()
	Engine.get_main_loop().root.add_child(world)
	world.new_game(2626)
	camera = GameCamera.new()
	camera.view_size_override = Vector2(720, 1280)
	world.add_child(camera)
	camera.focus_on_cell(world.start_cell)

	controller = BuildController.new()
	Engine.get_main_loop().root.add_child(controller)
	controller.setup(world, camera)
	GameSetup.create_starting_base(world)

	menu = BuildMenu.new()
	Engine.get_main_loop().root.add_child(menu)
	menu.setup(controller, world.research)

	bar = BuildBar.new()
	Engine.get_main_loop().root.add_child(bar)
	bar.setup(controller)


func after_each() -> void:
	for node: Node in [menu, bar, controller, world]:
		if is_instance_valid(node):
			node.free()
	world = null
	camera = null
	controller = null
	menu = null
	bar = null


func row(def_id: StringName) -> Button:
	return menu.find_child(String(def_id), true, false) as Button


func test_menu_lists_every_building() -> void:
	menu.open()
	for def_id: StringName in BuildingDefs.BUILD_ORDER:
		check(row(def_id) != null, "в меню нет здания %s" % def_id)


func test_locked_buildings_are_disabled_with_reason() -> void:
	menu.open()
	var accumulator: Button = row(BuildingDefs.ACCUMULATOR)
	check(accumulator.disabled, "закрытое здание должно быть недоступно")
	var detail: Label = accumulator.find_child("Detail", true, false) as Label
	check(detail.text.begins_with("Нужно:"), "игроку нужно видеть, какая технология нужна")

	world.research.complete(Technologies.POWER_STORAGE)
	menu.refresh()
	check(not row(BuildingDefs.ACCUMULATOR).disabled, "после исследования здание открывается")


func test_starter_buildings_are_available_immediately() -> void:
	# Сборщик обязателен для красных колб: закрыть его технологией — значит
	# запереть всё развитие игры на первом шаге.
	menu.open()
	for def_id: StringName in [BuildingDefs.DRILL, BuildingDefs.FURNACE, BuildingDefs.ASSEMBLER,
			BuildingDefs.LAB, BuildingDefs.STORAGE, BuildingDefs.SOLAR, BuildingDefs.DRONE_PORT]:
		check(not row(def_id).disabled, "%s должно быть доступно с начала игры" % def_id)


func test_row_shows_cost() -> void:
	menu.open()
	var detail: Label = row(BuildingDefs.DRILL).find_child("Detail", true, false) as Label
	check(detail.text.contains("Железная пластина"), "в строке должна быть цена: %s" % detail.text)


func test_unaffordable_building_is_still_selectable() -> void:
	# Выбрать здание заранее и достроить, когда подвезут материалы, — нормальный
	# сценарий, поэтому кнопка не блокируется.
	for building: Building in controller.pool.stores():
		building.output.clear()
	menu.open()
	check(not row(BuildingDefs.DRILL).disabled, "нехватка ресурсов не должна блокировать выбор")


func test_choosing_building_starts_build_mode_and_closes_menu() -> void:
	menu.open()
	row(BuildingDefs.SOLAR).pressed.emit()
	check(controller.is_building(), "выбор здания должен включать режим строительства")
	check_eq(controller.pending_def_id, BuildingDefs.SOLAR)
	check(not menu.is_open(), "меню должно закрываться после выбора")


func test_panel_closes_on_tap_outside() -> void:
	menu.open()
	var event := InputEventScreenTouch.new()
	event.pressed = true
	menu._on_dim_input(event)
	check(not menu.is_open(), "касание мимо панели должно закрывать лист")


func test_build_bar_appears_only_in_build_mode() -> void:
	check(not bar.visible, "без режима строительства панели быть не должно")
	controller.start_building(BuildingDefs.SOLAR)
	check(bar.visible, "панель подтверждения должна появиться")
	check_eq((bar.find_child("Title", true, false) as Label).text, "Солнечная панель")
	controller.cancel_building()
	check(not bar.visible, "после отмены панель скрывается")


func test_confirm_button_reflects_blocker() -> void:
	controller.start_building(BuildingDefs.SOLAR)
	controller.follow_center = false
	controller._move_ghost(world.start_cell)
	bar._process(0.016)
	var confirm: Button = bar.find_child("ConfirmButton", true, false) as Button
	check(confirm.disabled, "на занятом месте подтверждение должно быть недоступно")
	check_eq((bar.find_child("Hint", true, false) as Label).text, "Место занято")

	controller._move_ghost(world.start_cell + Vector2i(0, 6))
	bar._process(0.016)
	check(not confirm.disabled, "на свободном месте подтверждение доступно")


func test_confirm_and_cancel_buttons_work() -> void:
	controller.start_building(BuildingDefs.SOLAR)
	controller.follow_center = false
	controller._move_ghost(world.start_cell + Vector2i(0, 6))
	var before: int = world.buildings.count()

	(bar.find_child("ConfirmButton", true, false) as Button).pressed.emit()
	check_eq(world.buildings.count(), before + 1, "кнопка должна ставить здание")

	(bar.find_child("CancelButton", true, false) as Button).pressed.emit()
	check(not controller.is_building(), "кнопка отмены должна выключать режим")


func test_touch_targets_in_menu() -> void:
	menu.open()
	for def_id: StringName in BuildingDefs.BUILD_ORDER:
		check(
			row(def_id).custom_minimum_size.y >= UiTheme.TOUCH_MIN,
			"строка %s мельче цели касания" % def_id
		)


func test_unaffordable_row_names_the_missing_item_and_its_source() -> void:
	# Ровно тот случай, на который жаловался игрок: ресурсы вроде есть, а
	# котёл не строится. Не хватает кирпича, и это должно быть написано.
	world.research.complete(Technologies.STEAM_POWER)
	for building: Building in controller.pool.stores():
		building.output.clear()
		building.output.add(Items.IRON_PLATE, 100)
		building.output.add(Items.GEAR, 100)
	menu.open()

	var detail: Label = row(BuildingDefs.BOILER).find_child("Detail", true, false) as Label
	check(
		detail.text.contains(Items.display_name(Items.BRICK)),
		"в строке должен быть назван недостающий кирпич, получено: %s" % detail.text
	)
	check(
		not detail.text.contains(Items.display_name(Items.IRON_PLATE)),
		"того, чего хватает, в строке нехватки быть не должно: %s" % detail.text
	)
	check(
		detail.text.contains(BuildingDefs.display_name(BuildingDefs.FURNACE)),
		"строка должна подсказывать, где делают кирпич: %s" % detail.text
	)


func test_affordable_row_shows_plain_cost() -> void:
	menu.open()
	var detail: Label = row(BuildingDefs.DRILL).find_child("Detail", true, false) as Label
	check(
		not detail.text.begins_with("Не хватает"),
		"на бур ресурсов хватает с начала игры, получено: %s" % detail.text
	)
