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

var terrain_renderer: TerrainRenderer = null
var building_renderer: BuildingRenderer = null
var drone_renderer: DroneRenderer = null

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


## Создаёт новый мир. Возвращает стартовую клетку.
func new_game(seed_value: int) -> Vector2i:
	world_seed = seed_value
	grid = Grid.new(Constants.WORLD_SIZE)
	start_cell = MapGenerator.generate(grid, seed_value)
	buildings = BuildingRegistry.new(grid)
	research = ResearchState.new()

	terrain_renderer.setup(grid)
	building_renderer.setup(buildings)
	drone_renderer.setup(buildings, simulation)
	Events.world_generated.emit(seed_value)
	return start_cell


## Сообщает миру видимую область в мировых пикселях: от неё зависит,
## какие чанки держать загруженными и какие здания рисовать.
func update_view(visible_world_rect: Rect2) -> void:
	var cells: Rect2i = world_rect_to_cells(visible_world_rect)
	if cells == _visible_cells:
		return
	_visible_cells = cells
	terrain_renderer.update_visible(cells)
	building_renderer.set_view(cells)


func visible_cells() -> Rect2i:
	return _visible_cells


## Видимая область в клетках по прямоугольнику в мировых пикселях.
static func world_rect_to_cells(world_rect: Rect2) -> Rect2i:
	var from: Vector2i = Grid.world_to_cell(world_rect.position)
	var to: Vector2i = Grid.world_to_cell(world_rect.position + world_rect.size)
	return Rect2i(from, to - from + Vector2i.ONE)
