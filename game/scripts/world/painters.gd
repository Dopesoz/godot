class_name Painters
extends RefCounted

## Placeholder drawing routines for everything that stands *on* the map: walls,
## furniture and citizens (design doc §28).
##
## They are gathered in one file and take the canvas as an argument because
## DepthRenderer draws them all into a single canvas item, interleaved by depth.
## Splitting them into separate nodes is what makes a citizen appear in front of
## the wall they are standing behind — so the drawing code has to be callable
## from one place, and this is that place.
##
## Replacing a placeholder with real art means changing one function here.


# --- Walls ------------------------------------------------------------------

const WALL_TOP := Color(0.85, 0.83, 0.79)
const WALL_SIDE := Color(0.72, 0.70, 0.66)
const WALL_OUTLINE := Color(0.35, 0.33, 0.31, 0.8)
const DOOR_COLOR := Color(0.55, 0.36, 0.22)
const WINDOW_FRAME := Color(0.78, 0.76, 0.72)
const WINDOW_GLASS := Color(0.58, 0.78, 0.88, 0.75)
## After dark a window is the clearest sign that someone lives there. The colour
## is deliberately over-bright: the whole world canvas is being multiplied down
## by DayNight, and this has to survive that and still read as "lit".
const WINDOW_LIT := Color(3.2, 2.8, 1.7, 0.95)
## Doors are drawn shorter than the wall they sit in, so an opening reads as an
## opening even without art.
const DOOR_HEIGHT_RATIO := 0.62


static func draw_edge(canvas: CanvasItem, edge: Vector3i, type: int, floor_index: int = 0) -> void:
	match type:
		GameEnums.EdgeType.WALL:
			_wall(canvas, edge, float(GameConstants.WALL_HEIGHT), WALL_SIDE, floor_index)
		GameEnums.EdgeType.DOOR:
			_wall(canvas, edge, GameConstants.WALL_HEIGHT * DOOR_HEIGHT_RATIO, DOOR_COLOR, floor_index)
		GameEnums.EdgeType.WINDOW:
			_window(canvas, edge, floor_index)


static func _wall(canvas: CanvasItem, edge: Vector3i, height: float, color: Color, floor_index: int) -> void:
	var segment := IsoUtils.edge_segment(edge, floor_index)
	var lift := Vector2(0.0, -height)
	var quad := PackedVector2Array([segment[0], segment[1], segment[1] + lift, segment[0] + lift])
	canvas.draw_colored_polygon(quad, color)
	canvas.draw_line(segment[0] + lift, segment[1] + lift, WALL_TOP, 2.0)
	canvas.draw_polyline(quad + PackedVector2Array([quad[0]]), WALL_OUTLINE, 1.0)


## A window is a full-height wall with a lighter pane punched into it — the part
## that will glow at night in Phase 6.
static func _window(canvas: CanvasItem, edge: Vector3i, floor_index: int) -> void:
	_wall(canvas, edge, float(GameConstants.WALL_HEIGHT), WINDOW_FRAME, floor_index)
	var segment := IsoUtils.edge_segment(edge, floor_index)
	var a := segment[0].lerp(segment[1], 0.22)
	var b := segment[0].lerp(segment[1], 0.78)
	var low := Vector2(0.0, -GameConstants.WALL_HEIGHT * 0.28)
	var high := Vector2(0.0, -GameConstants.WALL_HEIGHT * 0.82)
	var glass := WINDOW_GLASS.lerp(WINDOW_LIT, 1.0 - GameClock.get_daylight())
	canvas.draw_colored_polygon(PackedVector2Array([a + low, b + low, b + high, a + high]), glass)


# --- Furniture --------------------------------------------------------------

const FURNITURE_HEIGHT := 20.0
const TOP_LIGHTEN := 0.18
const SIDE_DARKEN := 0.28
const FURNITURE_OUTLINE := Color(0.12, 0.12, 0.14, 0.55)
const SHADOW := Color(0.0, 0.0, 0.0, 0.18)
const IN_USE_GLOW := Color(1.0, 0.92, 0.55, 0.55)


static func draw_furniture(canvas: CanvasItem, item: Furniture) -> void:
	var template := item.data()
	if template == null:
		return
	var base := template.placeholder_color
	var height := FURNITURE_HEIGHT if template.blocks_movement else FURNITURE_HEIGHT * 0.55
	var lift := Vector2(0.0, -height)

	for cell in item.cells():
		var polygon := IsoUtils.cell_polygon(cell, item.floor_index)
		canvas.draw_colored_polygon(polygon, SHADOW)
		var top := PackedVector2Array()
		for point in polygon:
			top.append(point + lift)
		# Two visible side faces, then the lid: enough to read as a solid box.
		canvas.draw_colored_polygon(PackedVector2Array([polygon[1], polygon[2], top[2], top[1]]),
				base.darkened(SIDE_DARKEN))
		canvas.draw_colored_polygon(PackedVector2Array([polygon[2], polygon[3], top[3], top[2]]),
				base.darkened(SIDE_DARKEN * 0.5))
		canvas.draw_colored_polygon(top, base.lightened(TOP_LIGHTEN))
		var outline := IN_USE_GLOW if not item.users.is_empty() else FURNITURE_OUTLINE
		canvas.draw_polyline(top + PackedVector2Array([top[0]]), outline, 2.0 if not item.users.is_empty() else 1.0)


# --- Citizens ---------------------------------------------------------------

const BODY_HEIGHT := 26.0
const BODY_WIDTH := 13.0
const HEAD_RADIUS := 6.0
const CITIZEN_SHADOW := Color(0.0, 0.0, 0.0, 0.22)
const NAME_COLOR := Color(1.0, 1.0, 1.0, 0.92)
const NAME_SHADOW := Color(0.0, 0.0, 0.0, 0.75)

## Body tint per state, so what everyone is doing is readable at a glance
## without opening a panel — the point of the whole game (§34).
const STATE_COLORS := {
	GameEnums.CitizenState.IDLE: Color(0.78, 0.78, 0.82),
	GameEnums.CitizenState.WALKING: Color(0.85, 0.85, 0.88),
	GameEnums.CitizenState.EATING: Color(0.95, 0.72, 0.38),
	GameEnums.CitizenState.SLEEPING: Color(0.45, 0.52, 0.85),
	GameEnums.CitizenState.WORKING: Color(0.55, 0.72, 0.95),
	GameEnums.CitizenState.RELAXING: Color(0.55, 0.85, 0.62),
	GameEnums.CitizenState.SHOWERING: Color(0.50, 0.85, 0.92),
	GameEnums.CitizenState.SOCIALIZING: Color(0.92, 0.62, 0.80),
	GameEnums.CitizenState.GOING_HOME: Color(0.80, 0.78, 0.60),
}


static func draw_citizen(canvas: CanvasItem, citizen: Citizen, font: Font, show_name: bool) -> void:
	var ground := IsoUtils.cell_to_world_f(citizen.position, citizen.floor_index)
	canvas.draw_colored_polygon(_ellipse(ground, 10.0, 5.0), CITIZEN_SHADOW)

	var template := citizen.data()
	var skin: Color = template.placeholder_color if template != null else Color(0.9, 0.75, 0.6)
	var body: Color = STATE_COLORS.get(citizen.state, Color(0.8, 0.8, 0.8))

	var top := ground + Vector2(0.0, -BODY_HEIGHT)
	canvas.draw_colored_polygon(PackedVector2Array([
		ground + Vector2(-BODY_WIDTH * 0.5, 0.0),
		ground + Vector2(BODY_WIDTH * 0.5, 0.0),
		top + Vector2(BODY_WIDTH * 0.4, 0.0),
		top + Vector2(-BODY_WIDTH * 0.4, 0.0),
	]), body)
	canvas.draw_circle(top + Vector2(0.0, -HEAD_RADIUS * 0.6), HEAD_RADIUS, skin)

	if show_name:
		var label := citizen.citizen_name
		var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var origin := top + Vector2(-width * 0.5, -HEAD_RADIUS * 2.2)
		canvas.draw_string(font, origin + Vector2(1.0, 1.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, NAME_SHADOW)
		canvas.draw_string(font, origin, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, NAME_COLOR)


static func _ellipse(center: Vector2, radius_x: float, radius_y: float, points: int = 12) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for i in points:
		var angle := TAU * float(i) / float(points)
		polygon.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	return polygon
