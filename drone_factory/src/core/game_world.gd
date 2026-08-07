class_name GameWorld
extends Node2D

## Корень игрового мира: данные клеток и всё, что рисуется в мировых координатах.
##
## Узел-владелец: создаёт и связывает подсистемы, но сам не содержит игровой
## логики. Логика живёт в системах, данные — в Grid и реестрах.

var grid: Grid = null
var terrain_renderer: TerrainRenderer = null

var world_seed: int = 0
var start_cell: Vector2i = Vector2i.ZERO


func _ready() -> void:
	terrain_renderer = TerrainRenderer.new()
	terrain_renderer.name = "TerrainRenderer"
	add_child(terrain_renderer)


## Создаёт новый мир. Возвращает стартовую клетку.
func new_game(seed_value: int) -> Vector2i:
	world_seed = seed_value
	grid = Grid.new(Constants.WORLD_SIZE)
	start_cell = MapGenerator.generate(grid, seed_value)
	terrain_renderer.setup(grid)
	Events.world_generated.emit(seed_value)
	return start_cell


## Сообщает миру видимую область в мировых пикселях: от неё зависит,
## какие чанки держать загруженными.
func update_view(visible_world_rect: Rect2) -> void:
	terrain_renderer.update_visible(world_rect_to_cells(visible_world_rect))


## Видимая область в клетках по прямоугольнику в мировых пикселях.
static func world_rect_to_cells(world_rect: Rect2) -> Rect2i:
	var from: Vector2i = Grid.world_to_cell(world_rect.position)
	var to: Vector2i = Grid.world_to_cell(world_rect.position + world_rect.size)
	return Rect2i(from, to - from + Vector2i.ONE)
