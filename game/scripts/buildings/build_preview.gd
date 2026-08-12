extends Node2D

## Draws what the current build action would do, in the colour of whether it is
## allowed. The player should never have to click to find out.
##
## It renders BuildController's plan and holds no rules of its own — the
## controller already decided what is valid and what it costs.

const VALID_FILL := Color(0.45, 0.95, 0.55, 0.30)
const VALID_LINE := Color(0.55, 1.0, 0.65, 0.95)
const INVALID_FILL := Color(1.0, 0.35, 0.32, 0.28)
const INVALID_LINE := Color(1.0, 0.45, 0.4, 0.95)
const COST_COLOR := Color(1.0, 1.0, 1.0)

@onready var _builder: BuildController = get_parent().get_node("Builder") as BuildController

var _font: Font
var _was_building: bool = false


func _ready() -> void:
	_font = ThemeDB.fallback_font


func _process(_delta: float) -> void:
	# The plan changes as the pointer moves, so this layer is the one place in
	# the project that legitimately redraws every frame — but only while a build
	# tool is active, plus one final frame to clear the last preview.
	var building := _builder != null and _builder.is_building()
	if building or _was_building:
		queue_redraw()
	_was_building = building


func _draw() -> void:
	if _builder == null or not _builder.is_building():
		return
	var fill := VALID_FILL if _builder.preview_valid else INVALID_FILL
	var line := VALID_LINE if _builder.preview_valid else INVALID_LINE

	for cell: Vector2i in _builder.preview_cells:
		draw_colored_polygon(IsoUtils.cell_polygon(cell), fill)

	for edge: Vector3i in _builder.preview_edges:
		var segment := IsoUtils.edge_segment(edge)
		var lift := Vector2(0.0, -GameConstants.WALL_HEIGHT)
		draw_colored_polygon(PackedVector2Array([
			segment[0], segment[1], segment[1] + lift, segment[0] + lift
		]), fill)
		draw_line(segment[0], segment[1], line, 2.0)
		draw_line(segment[0] + lift, segment[1] + lift, line, 2.0)

	_draw_cost()


func _draw_cost() -> void:
	if _builder.preview_cost <= 0:
		return
	var anchor := _builder.preview_edges[0] if not _builder.preview_edges.is_empty() else Vector3i.ZERO
	var cell := Vector2i(anchor.x, anchor.y)
	if not _builder.preview_cells.is_empty():
		cell = _builder.preview_cells[0]
	var position := IsoUtils.cell_to_world(cell) + Vector2(12.0, -GameConstants.WALL_HEIGHT - 12.0)
	var text := "$%d" % _builder.preview_cost
	draw_string(_font, position + Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0, 0, 0, 0.7))
	draw_string(_font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, COST_COLOR)
