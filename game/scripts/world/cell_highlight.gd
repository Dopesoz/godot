extends Node2D

## Highlights the cell under the pointer.
##
## Redraws only when the hovered cell actually changes, not every frame — a
## habit worth keeping from the start, since by Phase 8 there will be a lot of
## nodes that could otherwise redraw needlessly.

const FILL_COLOR := Color(1.0, 0.93, 0.6, 0.28)
const OUTLINE_COLOR := Color(1.0, 0.93, 0.6, 0.85)

@onready var _world: WorldController = get_parent() as WorldController

var _shown_cell: Vector2i = Vector2i(-2, -2)


func _process(_delta: float) -> void:
	if _world == null:
		return
	if _world.hovered_cell != _shown_cell:
		_shown_cell = _world.hovered_cell
		queue_redraw()


func _draw() -> void:
	if _shown_cell.x < 0:
		return
	var polygon := IsoUtils.cell_polygon(_shown_cell)
	draw_colored_polygon(polygon, FILL_COLOR)
	draw_polyline(polygon + PackedVector2Array([polygon[0]]), OUTLINE_COLOR, 2.0)
