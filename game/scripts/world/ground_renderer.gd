extends Node2D

## Draws the ground: one isometric diamond per cell.
##
## Placeholder art per design doc §28 — flat colours, no textures. What matters
## now is that the projection, the draw order and the redraw triggers are right;
## swapping `draw_colored_polygon` for a sprite later changes this file only.
##
## Performance note: Godot caches the commands issued in `_draw`, so a 40x40 map
## costs 1600 polygons once, not per frame. Around Phase 9 (a much bigger city)
## this gets replaced by chunked layers that only redraw the chunk that changed;
## the redraw triggers below are already per-cell for that reason.

const GRASS_A := Color(0.36, 0.52, 0.31)
const GRASS_B := Color(0.33, 0.49, 0.29)
const FLOOR_FALLBACK := Color(0.62, 0.51, 0.38)
const EDGE_COLOR := Color(0.0, 0.0, 0.0, 0.10)

var _grid: WorldGrid


func _ready() -> void:
	EventBus.world_ready.connect(_on_world_ready)
	EventBus.cell_changed.connect(_on_cell_changed)


func _on_world_ready(world: WorldGrid) -> void:
	_grid = world
	queue_redraw()


func _on_cell_changed(_cell: Vector2i, _floor_index: int) -> void:
	queue_redraw()


func _draw() -> void:
	if _grid == null:
		return
	for y in _grid.size.y:
		for x in _grid.size.x:
			var cell := Vector2i(x, y)
			var polygon := IsoUtils.cell_polygon(cell)
			draw_colored_polygon(polygon, _color_for(cell))
			# Closing the loop back to the first point outlines the diamond.
			draw_polyline(polygon + PackedVector2Array([polygon[0]]), EDGE_COLOR, 1.0)


func _color_for(cell: Vector2i) -> Color:
	var data := _grid.get_cell(cell)
	if data != null and data.floor_id != &"":
		var furniture := Database.get_furniture(data.floor_id)
		return furniture.placeholder_color if furniture != null else FLOOR_FALLBACK
	# Checkerboard so individual cells stay readable without a grid overlay.
	return GRASS_A if (cell.x + cell.y) % 2 == 0 else GRASS_B
