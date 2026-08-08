class_name GameWorld
extends Node2D

## Корень игрового мира: данные клеток, здания и всё, что рисуется в мировых
## координатах.
##
## Узел-владелец: создаёт и связывает подсистемы, но сам не содержит игровой
## логики. Логика живёт в системах, данные — в Grid и реестрах.

var grid: Grid = null
var buildings: BuildingRegistry = null
## Изученные технологии и их бонусы: читают и здания, и интерфейс.
var research: ResearchState = null
## Накопительная статистика партии: достижения и задачи считают по ней.
var stats: GameStats = GameStats.new()

var terrain_renderer: TerrainRenderer = null
var building_renderer: BuildingRenderer = null
var drone_renderer: DroneRenderer = null
## Носильщики рисуются отдельным слоем: другой спрайт — другой MultiMesh.
var porter_renderer: DroneRenderer = null

## Ссылка на симуляцию нужна только отрисовке дронов — для интерполяции.
var simulation: Simulation = null

var world_seed: int = 0
var start_cell: Vector2i = Vector2i.ZERO

var _visible_cells := Rect2i(0, 0, 0, 0)


func _ready() -> void:
	terrain_renderer = TerrainRenderer.new()
	terrain_renderer.name = "TerrainRenderer"
	add_child(terrain_renderer)

	building_renderer = BuildingRenderer.new()
	building_renderer.name = "BuildingRenderer"
	add_child(building_renderer)

	drone_renderer = DroneRenderer.new()
	drone_renderer.name = "DroneRenderer"
	add_child(drone_renderer)

	porter_renderer = DroneRenderer.new()
	porter_renderer.name = "PorterRenderer"
	# Вид и спрайт задаются до входа в дерево: меш собирается в _ready().
	porter_renderer.courier_kind = BuildingDefs.Kind.PORTER_HUT
	porter_renderer.sprite_key = ObjectArt.PORTER
	add_child(porter_renderer)


## Создаёт новый мир. Возвращает стартовую клетку.
func new_game(seed_value: int) -> Vector2i:
	world_seed = seed_value
	grid = Grid.new(Constants.WORLD_SIZE)
	start_cell = MapGenerator.generate(grid, seed_value)
	buildings = BuildingRegistry.new(grid)
	research = ResearchState.new()
	stats = GameStats.new()

	terrain_renderer.setup(grid)
	building_renderer.setup(buildings)
	drone_renderer.setup(buildings, simulation)
	porter_renderer.setup(buildings, simulation)
	Events.world_generated.emit(seed_value)
	return start_cell


## Готовит мир к загрузке сохранения: пустые слои нужного размера и чистые
## реестры. Мир не генерируется заново — его слои приедут из файла.
##
## Объекты состояния именно очищаются, а не создаются заново, и это важно.
## Интерфейс и строительство получают ссылки на сетку, реестр и исследования
## один раз при старте партии. Если подменить объект здесь, у них останется
## указатель на прежний: фабрика продолжит работать (системы читают состояние
## через контекст тика), а меню будет показывать пустое дерево технологий —
## ровно то, что выглядело как «исследования пропали после перезапуска».
func prepare_for_load(seed_value: int) -> void:
	world_seed = seed_value
	if grid == null or grid.size != Constants.WORLD_SIZE:
		grid = Grid.new(Constants.WORLD_SIZE)
	else:
		grid.clear()
	if buildings == null:
		buildings = BuildingRegistry.new(grid)
	else:
		buildings.clear()
		buildings.grid = grid
	if research == null:
		research = ResearchState.new()
	else:
		research.clear()
	if stats == null:
		stats = GameStats.new()
	else:
		stats.clear()
	terrain_renderer.setup(grid)
	building_renderer.setup(buildings)
	drone_renderer.setup(buildings, simulation)
	porter_renderer.setup(buildings, simulation)
	_visible_cells = Rect2i(0, 0, 0, 0)


## Досборка после загрузки: подтягиваем видимые чанки, чтобы первый кадр
## был уже полным.
func after_load(visible_world_rect: Rect2) -> void:
	update_view(visible_world_rect)
	terrain_renderer.flush_pending()
	building_renderer.mark_dirty()
	Events.world_generated.emit(world_seed)


## Сообщает миру видимую область в мировых пикселях: от неё зависит,
## какие чанки держать загруженными и какие здания рисовать.
func update_view(visible_world_rect: Rect2) -> void:
	var cells: Rect2i = world_rect_to_cells(visible_world_rect)
	if cells == _visible_cells:
		return
	_visible_cells = cells
	terrain_renderer.update_visible(cells)
	building_renderer.set_view(cells)


## Куда возвращать камеру по кнопке «К базе»: порт дронов, если он есть,
## иначе стартовая клетка. Порт — настоящий центр фабрики, а стартовая
## клетка остаётся запасным вариантом, если игрок снёс всё подчистую.
func home_cell() -> Vector2i:
	if buildings != null:
		var ports: Array[Building] = buildings.of_kind(BuildingDefs.Kind.DRONE_PORT)
		if not ports.is_empty():
			return ports[0].center_cell()
		var all_buildings: Array[Building] = buildings.all()
		if not all_buildings.is_empty():
			return all_buildings[0].center_cell()
	return start_cell


func visible_cells() -> Rect2i:
	return _visible_cells


## Видимая область в клетках по прямоугольнику в мировых пикселях.
static func world_rect_to_cells(world_rect: Rect2) -> Rect2i:
	var from: Vector2i = Grid.world_to_cell(world_rect.position)
	var to: Vector2i = Grid.world_to_cell(world_rect.position + world_rect.size)
	return Rect2i(from, to - from + Vector2i.ONE)
