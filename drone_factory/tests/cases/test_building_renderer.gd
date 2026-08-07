extends TestCase
## Отрисовка зданий: выборка по области, значки состояний, призрак постройки.

var world: GameWorld = null


func before_each() -> void:
	world = GameWorld.new()
	Engine.get_main_loop().root.add_child(world)
	world.new_game(777)
	world.update_view(Rect2(Grid.cell_to_world(world.start_cell) - Vector2(200, 200), Vector2(400, 400)))


func after_each() -> void:
	if is_instance_valid(world):
		world.free()
	world = null


func _place(def_id: StringName, offset: Vector2i) -> Building:
	return world.buildings.place(def_id, world.start_cell + offset)


func test_in_rect_selects_only_visible_buildings() -> void:
	var near: Building = _place(BuildingDefs.STORAGE, Vector2i(0, 0))
	check(near != null, "склад не поставился на стартовой площадке")
	var area := Rect2i(world.start_cell - Vector2i(2, 2), Vector2i(6, 6))
	check(world.buildings.in_rect(area).has(near), "здание в области не найдено")

	var far_area := Rect2i(world.start_cell + Vector2i(60, 60), Vector2i(4, 4))
	check(not world.buildings.in_rect(far_area).has(near), "здание вне области попало в выборку")


func test_partially_visible_building_is_included() -> void:
	# Здание, задевающее край экрана, должно рисоваться, иначе оно «мигает».
	var building: Building = _place(BuildingDefs.STORAGE, Vector2i(0, 0))
	var area := Rect2i(building.origin + Vector2i(1, 1), Vector2i(4, 4))
	check(world.buildings.in_rect(area).has(building), "частично видимое здание пропало")


func test_badges_reflect_status() -> void:
	var building: Building = _place(BuildingDefs.FURNACE, Vector2i(0, 0))
	building.status = Building.Status.NO_POWER
	check_eq(BuildingRenderer._badge_for(building), ObjectArt.BADGE_NO_POWER)
	building.status = Building.Status.OUTPUT_FULL
	check_eq(BuildingRenderer._badge_for(building), ObjectArt.BADGE_FULL)
	building.status = Building.Status.WORKING
	check_eq(BuildingRenderer._badge_for(building), &"", "работающее здание значка не получает")


func test_ghost_state_is_tracked() -> void:
	var renderer: BuildingRenderer = world.building_renderer
	renderer.set_ghost(BuildingDefs.SOLAR, world.start_cell, true)
	check_eq(renderer.ghost_def_id, BuildingDefs.SOLAR)
	check(renderer.ghost_valid)
	renderer.clear_ghost()
	check_eq(renderer.ghost_def_id, &"", "призрак должен сниматься")


func test_redraw_is_requested_only_on_change() -> void:
	var renderer: BuildingRenderer = world.building_renderer
	renderer._process(0.016)
	check(not renderer._dirty, "после перерисовки флаг должен сбрасываться")

	renderer.set_view(world.visible_cells())
	check(not renderer._dirty, "та же область не должна вызывать перерисовку")

	renderer.set_ghost(BuildingDefs.SOLAR, world.start_cell, true)
	check(renderer._dirty, "смена призрака должна помечать на перерисовку")


func test_placing_building_marks_dirty() -> void:
	var renderer: BuildingRenderer = world.building_renderer
	renderer._process(0.016)
	_place(BuildingDefs.STORAGE, Vector2i(0, 0))
	check(renderer._dirty, "постройка должна вызывать перерисовку")


func test_selection_follows_event() -> void:
	var building: Building = _place(BuildingDefs.STORAGE, Vector2i(0, 0))
	Events.selection_changed.emit(building.id)
	check_eq(world.building_renderer.selected_id, building.id)
	Events.selection_changed.emit(-1)
	check_eq(world.building_renderer.selected_id, 0, "снятие выделения")


func test_draw_runs_without_errors() -> void:
	# Прямой вызов _draw() ловит опечатки в регионах и подписях API отрисовки.
	_place(BuildingDefs.STORAGE, Vector2i(0, 0))
	_place(BuildingDefs.SOLAR, Vector2i(3, 0))
	world.building_renderer.selected_id = 1
	world.building_renderer.set_ghost(BuildingDefs.FURNACE, world.start_cell + Vector2i(6, 0), false)
	world.building_renderer._draw()
	check(true, "отрисовка не должна падать")
