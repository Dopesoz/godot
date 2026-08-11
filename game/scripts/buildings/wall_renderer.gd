extends Node2D

## Draws walls, doors and windows as 2.5D quads standing on cell borders.
##
## The base of a wall is one side of a cell diamond; the wall itself is that
## segment extruded straight up by WALL_HEIGHT. Placeholder colours per §28.
##
## Draw order matters as soon as walls overlap: a wall further "north" must be
## painted before the ones in front of it. Edges are therefore sorted by depth
## before drawing, which is the same ordering the Y-sorted entity layer will use
## for furniture and citizens.

const WALL_TOP := Color(0.85, 0.83, 0.79)
const WALL_SIDE := Color(0.72, 0.70, 0.66)
const WALL_OUTLINE := Color(0.35, 0.33, 0.31, 0.8)
const DOOR_COLOR := Color(0.55, 0.36, 0.22)
const WINDOW_FRAME := Color(0.78, 0.76, 0.72)
const WINDOW_GLASS := Color(0.58, 0.78, 0.88, 0.75)

## Doors are drawn shorter than the wall they sit in, so an opening reads as an
## opening at a glance even without art.
const DOOR_HEIGHT_RATIO := 0.62

var _grid: WorldGrid


func _ready() -> void:
	EventBus.world_ready.connect(_on_world_ready)
	EventBus.edge_changed.connect(_on_edge_changed)


func _on_world_ready(world: WorldGrid) -> void:
	_grid = world
	queue_redraw()


func _on_edge_changed(_edge: Vector3i, _floor_index: int) -> void:
	queue_redraw()


func _draw() -> void:
	if _grid == null:
		return
	for edge in _sorted_edges():
		var type: int = _grid.get_edge(edge)
		match type:
			GameEnums.EdgeType.WALL:
				_draw_wall(edge, float(GameConstants.WALL_HEIGHT), WALL_SIDE)
			GameEnums.EdgeType.DOOR:
				_draw_wall(edge, GameConstants.WALL_HEIGHT * DOOR_HEIGHT_RATIO, DOOR_COLOR)
			GameEnums.EdgeType.WINDOW:
				_draw_window(edge)


## Back to front. In this projection a cell's depth is x + y; an edge belongs to
## the cell it is stored on, and vertical edges sit half a step further back.
func _sorted_edges() -> Array:
	var edges := _grid.used_edges()
	edges.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		var depth_a := float(a.x + a.y) + (0.0 if a.z == GameEnums.EdgeAxis.HORIZONTAL else 0.5)
		var depth_b := float(b.x + b.y) + (0.0 if b.z == GameEnums.EdgeAxis.HORIZONTAL else 0.5)
		return depth_a < depth_b)
	return edges


func _draw_wall(edge: Vector3i, height: float, color: Color) -> void:
	var segment := IsoUtils.edge_segment(edge)
	var lift := Vector2(0.0, -height)
	var quad := PackedVector2Array([
		segment[0], segment[1], segment[1] + lift, segment[0] + lift
	])
	draw_colored_polygon(quad, color)
	draw_line(segment[0] + lift, segment[1] + lift, WALL_TOP, 2.0)
	draw_polyline(quad + PackedVector2Array([quad[0]]), WALL_OUTLINE, 1.0)


## A window is a full-height wall with a lighter pane punched into the middle
## third — enough to read as glass, and it will later be what glows at night.
func _draw_window(edge: Vector3i) -> void:
	_draw_wall(edge, float(GameConstants.WALL_HEIGHT), WINDOW_FRAME)
	var segment := IsoUtils.edge_segment(edge)
	var a := segment[0].lerp(segment[1], 0.22)
	var b := segment[0].lerp(segment[1], 0.78)
	var low := Vector2(0.0, -GameConstants.WALL_HEIGHT * 0.28)
	var high := Vector2(0.0, -GameConstants.WALL_HEIGHT * 0.82)
	draw_colored_polygon(PackedVector2Array([a + low, b + low, b + high, a + high]), WINDOW_GLASS)
