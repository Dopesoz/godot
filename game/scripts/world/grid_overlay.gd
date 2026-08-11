extends Node2D

## Optional grid lines over the ground, toggled with G.
##
## Drawn as two families of parallel lines rather than 1600 separate diamonds:
## in an isometric projection every cell border lies on one of two directions,
## so the whole 40x40 grid costs 82 lines instead of 6400 segments.

const LINE_COLOR := Color(1.0, 1.0, 1.0, 0.13)

var _grid: WorldGrid


func _ready() -> void:
	EventBus.world_ready.connect(_on_world_ready)


func _on_world_ready(world: WorldGrid) -> void:
	_grid = world
	queue_redraw()


func _unhandled_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed(InputActions.TOGGLE_GRID):
		visible = not visible


func _draw() -> void:
	if _grid == null:
		return
	var size := _grid.size
	# Lines of constant x (running along +y) and of constant y (running along +x).
	for x in size.x + 1:
		draw_line(IsoUtils.cell_to_world_f(Vector2(x - 0.5, -0.5)),
				IsoUtils.cell_to_world_f(Vector2(x - 0.5, size.y - 0.5)), LINE_COLOR, 1.0)
	for y in size.y + 1:
		draw_line(IsoUtils.cell_to_world_f(Vector2(-0.5, y - 0.5)),
				IsoUtils.cell_to_world_f(Vector2(size.x - 0.5, y - 0.5)), LINE_COLOR, 1.0)
