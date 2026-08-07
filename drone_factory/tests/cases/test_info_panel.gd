extends TestCase
## Панель здания: состояние, содержимое, рецепты, очередь, действия.

var world: GameWorld = null
var camera: GameCamera = null
var controller: BuildController = null
var panel: InfoPanel = null


func before_each() -> void:
	world = GameWorld.new()
	Engine.get_main_loop().root.add_child(world)
	world.new_game(2727)
	for i: int in world.grid.size * world.grid.size:
		world.grid.terrain[i] = TileTypes.Terrain.GRASS

	camera = GameCamera.new()
	camera.view_size_override = Vector2(720, 1280)
	world.add_child(camera)
	camera.focus_on_cell(world.start_cell)

	controller = BuildController.new()
	Engine.get_main_loop().root.add_child(controller)
	controller.setup(world, camera)
	GameSetup.create_starting_base(world)

	panel = InfoPanel.new()
	Engine.get_main_loop().root.add_child(panel)
	panel.setup(world, controller)


func after_each() -> void:
	for node: Node in [panel, controller, world]:
		if is_instance_valid(node):
			node.free()
	world = null
	camera = null
	controller = null
	panel = null


func place(def_id: StringName, offset: Vector2i) -> Building:
	return world.buildings.place(def_id, world.start_cell + offset)


func test_panel_opens_on_selection() -> void:
	var furnace: Building = place(BuildingDefs.FURNACE, Vector2i(6, 6))
	check(not panel.is_open())
	controller.select(furnace.id)
	check(panel.is_open(), "выбор здания должен открывать панель")
	check_eq(panel.selected_building(), furnace)
	controller.select(0)
	check(not panel.is_open(), "снятие выбора закрывает панель")


func test_panel_shows_status_and_power() -> void:
	var furnace: Building = place(BuildingDefs.FURNACE, Vector2i(6, 6))
	furnace.status = Building.Status.NO_POWER
	furnace.power_satisfaction = 0.0
	controller.select(furnace.id)
	check(panel._status_label.text.contains("Нет энергии"))
	check(panel._status_label.text.contains("кВт"), "потребление должно быть видно")


func test_recipes_are_listed_and_selectable() -> void:
	var furnace: Furnace = place(BuildingDefs.FURNACE, Vector2i(6, 6)) as Furnace
	controller.select(furnace.id)
	var button: Button = panel.find_child(String(Recipes.SMELT_IRON), true, false) as Button
	check(button != null, "рецепт плавки железа должен быть в списке")
	button.pressed.emit()
	check_eq(furnace.current_recipe(), Recipes.SMELT_IRON, "тап по рецепту должен его назначать")


func test_locked_recipes_are_hidden() -> void:
	var furnace: Furnace = place(BuildingDefs.FURNACE, Vector2i(6, 6)) as Furnace
	controller.select(furnace.id)
	check_eq(panel.find_child(String(Recipes.SMELT_STEEL), true, false), null, "сталь ещё не изучена")
	world.research.complete(Technologies.STEEL)
	panel.refresh()
	check(panel.find_child(String(Recipes.SMELT_STEEL), true, false) != null,
		"после исследования рецепт должен появиться")


func test_queue_is_shown_and_editable() -> void:
	var furnace: Furnace = place(BuildingDefs.FURNACE, Vector2i(6, 6)) as Furnace
	furnace.set_recipe(Recipes.SMELT_IRON, 5)
	controller.select(furnace.id)
	var job: Button = panel.find_child("Job0", true, false) as Button
	check(job != null, "задание должно быть в списке очереди")
	check(job.text.contains("5"), "количество должно быть видно: %s" % job.text)
	job.pressed.emit()
	check_eq(furnace.queue_size(), 0, "тап по заданию должен его убирать")


func test_repeat_job_is_marked() -> void:
	var furnace: Furnace = place(BuildingDefs.FURNACE, Vector2i(6, 6)) as Furnace
	furnace.set_recipe(Recipes.SMELT_IRON, ProductionBuilding.REPEAT)
	controller.select(furnace.id)
	check((panel.find_child("Job0", true, false) as Button).text.contains("∞"))


func test_drill_shows_ore_left() -> void:
	var patch: Vector2i = world.start_cell + Vector2i(8, 8)
	for dy: int in 2:
		for dx: int in 2:
			world.grid.set_ore(patch + Vector2i(dx, dy), TileTypes.Ore.COPPER, 300)
	var drill: Building = world.buildings.place(BuildingDefs.DRILL, patch)
	controller.select(drill.id)
	var found: bool = false
	for child: Node in panel._details.get_children():
		if child is Label and (child as Label).text.contains("Медная руда"):
			found = true
	check(found, "панель бура должна показывать тип руды")


func test_inventory_is_shown() -> void:
	var storage: Building = place(BuildingDefs.STORAGE, Vector2i(6, 6))
	storage.output.add(Items.GEAR, 12)
	controller.select(storage.id)
	var text: String = ""
	for child: Node in panel._details.get_children():
		if child is Label:
			text += (child as Label).text
	check(text.contains("Выдача"), "содержимое склада должно быть видно")


func test_toggle_and_demolish() -> void:
	var furnace: Building = place(BuildingDefs.FURNACE, Vector2i(6, 6))
	controller.select(furnace.id)

	(panel.find_child("PowerButton", true, false) as Button).pressed.emit()
	check(not furnace.enabled, "кнопка должна выключать здание")
	check_eq((panel.find_child("PowerButton", true, false) as Button).text, "Включить")

	var before: int = world.buildings.count()
	(panel.find_child("DemolishButton", true, false) as Button).pressed.emit()
	check_eq(world.buildings.count(), before - 1, "здание должно быть разобрано")
	check(not panel.is_open(), "после сноса панель закрывается")


func test_panel_closes_when_building_disappears() -> void:
	var furnace: Building = place(BuildingDefs.FURNACE, Vector2i(6, 6))
	controller.select(furnace.id)
	world.buildings.remove(furnace.id)
	check(not panel.is_open(), "панель снесённого здания должна закрыться")


func test_reselect_after_close_works() -> void:
	# Закрытие панели снимает выбор, иначе повторный тап по тому же зданию
	# не открыл бы её снова.
	var furnace: Building = place(BuildingDefs.FURNACE, Vector2i(6, 6))
	controller.select(furnace.id)
	panel.close()
	check_eq(controller.selected_id, 0)
	controller.select(furnace.id)
	check(panel.is_open())
