class_name Painters
extends RefCounted

## Drawing routines for everything that stands *on* the map: walls, furniture
## and citizens.
##
## They are gathered in one file and take the canvas as an argument because
## DepthRenderer draws them all into a single canvas item, interleaved by depth.
## Splitting them into separate nodes is what makes a citizen appear in front of
## the wall they are standing behind — so the drawing code has to be callable
## from one place, and this is that place.
##
## Every routine has two paths: the sprite from Art, and the coloured block it
## drew before any art existed (design doc §28). The fallback is not dead code —
## it is what a newly added object looks like until someone draws it, and it is
## what the headless self-test exercises.
##
## Citizens are the exception: they stay drawn from code. A resident's shirt,
## hair and skin vary per person and their pose comes from what the model says
## they are doing, so a handful of shapes gives more variety than a sprite sheet
## would, and can never disagree with the simulation.


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
const WINDOW_LIT := Color(2.6, 2.15, 1.20, 0.88)
## Doors are drawn shorter than the wall they sit in, so an opening reads as an
## opening even without art.
const DOOR_HEIGHT_RATIO := 0.62
## How much of a wall survives when it is cut away, in pixels measured up from
## the bottom of its sprite. Enough to see there is a wall, low enough to see
## over it.
const CUTAWAY_BAND := 18.0


## `cutaway` means this wall stands between the camera and a room, so it is
## drawn as a low stub instead of a full wall — otherwise the player would be
## looking at the outside of a box (design doc §11, §34).
static func draw_edge(canvas: CanvasItem, edge: Vector3i, type: int, floor_index: int = 0,
		cutaway: bool = false) -> void:
	var texture := Art.wall_texture(type, edge.z)
	if texture != null:
		var rect := Art.wall_rect(edge, floor_index)
		if cutaway:
			var band := minf(CUTAWAY_BAND, rect.size.y)
			var source := Rect2(0.0, float(texture.get_height()) - band * Art.SPRITE_SCALE,
					float(texture.get_width()), band * Art.SPRITE_SCALE)
			canvas.draw_texture_rect_region(texture,
					Rect2(rect.position.x, rect.end.y - band, rect.size.x, band), source)
		else:
			canvas.draw_texture_rect(texture, rect, false)
			if type == GameEnums.EdgeType.WINDOW:
				_window_glow(canvas, edge, floor_index)
		return

	var height_scale := (CUTAWAY_BAND / (GameConstants.TILE_HH + GameConstants.WALL_HEIGHT)) if cutaway else 1.0
	match type:
		GameEnums.EdgeType.WALL:
			_wall(canvas, edge, GameConstants.WALL_HEIGHT * height_scale, WALL_SIDE, floor_index)
		GameEnums.EdgeType.DOOR:
			_wall(canvas, edge, GameConstants.WALL_HEIGHT * DOOR_HEIGHT_RATIO * height_scale,
					DOOR_COLOR, floor_index)
		GameEnums.EdgeType.WINDOW:
			if cutaway:
				_wall(canvas, edge, GameConstants.WALL_HEIGHT * height_scale, WINDOW_FRAME, floor_index)
			else:
				_window(canvas, edge, floor_index)


## The pane, painted over the sprite once the sun is down. Drawn from the same
## fractions the sprite was generated with, so it lands on the glass and not on
## the frame.
static func _window_glow(canvas: CanvasItem, edge: Vector3i, floor_index: int) -> void:
	var night := 1.0 - GameClock.get_daylight()
	if night <= 0.05:
		return
	var glow := WINDOW_LIT
	glow.a *= night
	canvas.draw_colored_polygon(PackedVector2Array([
		Art.wall_point(edge, Art.PANE_X.x, Art.PANE_Z.x, floor_index),
		Art.wall_point(edge, Art.PANE_X.y, Art.PANE_Z.x, floor_index),
		Art.wall_point(edge, Art.PANE_X.y, Art.PANE_Z.y, floor_index),
		Art.wall_point(edge, Art.PANE_X.x, Art.PANE_Z.y, floor_index),
	]), glow)


static func _wall(canvas: CanvasItem, edge: Vector3i, height: float, color: Color, floor_index: int) -> void:
	var segment := IsoUtils.edge_segment(edge, floor_index)
	var lift := Vector2(0.0, -height)
	var quad := PackedVector2Array([segment[0], segment[1], segment[1] + lift, segment[0] + lift])
	canvas.draw_colored_polygon(quad, color)
	canvas.draw_line(segment[0] + lift, segment[1] + lift, WALL_TOP, 2.0)
	canvas.draw_polyline(quad + PackedVector2Array([quad[0]]), WALL_OUTLINE, 1.0)


## A window is a full-height wall with a lighter pane punched into it.
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
	var in_use := not item.users.is_empty()
	if in_use:
		# A pool of light around the base, rather than an outline on top: it
		# reads at any zoom and does not depend on how tall the object is.
		var glow := IN_USE_GLOW
		glow.a *= 0.26 + 0.22 * sin(float(Time.get_ticks_msec()) * 0.004)
		canvas.draw_colored_polygon(
				Art.footprint_polygon(item.origin, item.size(), item.floor_index, 0.30), glow)

	var texture := Art.furniture_texture(template.id, item.rotation_steps % 2 == 1)
	if texture != null:
		canvas.draw_texture_rect(texture,
				Art.furniture_rect(item.origin, item.size(), texture, item.floor_index), false)
		return

	_furniture_block(canvas, item, template, in_use)


## The pre-art placeholder: a coloured box per cell (design doc §28).
static func _furniture_block(canvas: CanvasItem, item: Furniture, template: FurnitureData,
		in_use: bool) -> void:
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
		canvas.draw_polyline(top + PackedVector2Array([top[0]]),
				IN_USE_GLOW if in_use else FURNITURE_OUTLINE, 2.0 if in_use else 1.0)


# --- Cars -------------------------------------------------------------------

## Cars are drawn like furniture that happens to move: one cell of footprint,
## bottom edge pinned to the cell they are on, so they sit on the road the same
## way a sofa sits on a floor.
static func draw_car(canvas: CanvasItem, car: Traffic.Car) -> void:
	var texture := Art.car_texture(car.color_index, car.coming(), car.along_x())
	var cell := Vector2i(floori(car.position.x), floori(car.position.y))
	if texture == null:
		canvas.draw_colored_polygon(Art.footprint_polygon(cell, Vector2i.ONE, 0, -0.2),
				Color(0.8, 0.3, 0.3))
		return
	var rect := Art.furniture_rect(cell, Vector2i.ONE, texture)
	# The fractional part of the position is the car's progress between cells.
	var drift := car.position - Vector2(cell)
	rect.position += IsoUtils.cell_to_world_f(drift) - IsoUtils.cell_to_world_f(Vector2.ZERO)
	canvas.draw_texture_rect(texture, rect, false)


# --- Citizens ---------------------------------------------------------------

const BODY_HEIGHT := 20.0
const BODY_WIDTH := 11.0
const HEAD_RADIUS := 5.5
const LEG_HEIGHT := 8.0
const CITIZEN_SHADOW := Color(0.0, 0.0, 0.0, 0.22)
const NAME_COLOR := Color(1.0, 1.0, 1.0, 0.92)
const NAME_SHADOW := Color(0.0, 0.0, 0.0, 0.75)
const SELECTION_RING := Color(1.0, 0.93, 0.6, 0.9)
const TROUSERS := Color(0.28, 0.30, 0.38)
const EYE := Color(0.15, 0.14, 0.18, 0.85)

## Wardrobe. A resident keeps the same shirt for their whole life because it is
## picked from their id — two people in one room are told apart at a glance,
## with nothing stored and nothing to save.
const SHIRTS := [
	Color(0.86, 0.42, 0.38), Color(0.36, 0.55, 0.80), Color(0.42, 0.66, 0.48),
	Color(0.90, 0.72, 0.34), Color(0.62, 0.45, 0.75), Color(0.32, 0.66, 0.68),
	Color(0.88, 0.56, 0.32), Color(0.55, 0.58, 0.64),
]
const HAIR := [
	Color(0.18, 0.14, 0.12), Color(0.35, 0.22, 0.13), Color(0.55, 0.38, 0.20),
	Color(0.75, 0.62, 0.35), Color(0.42, 0.24, 0.18), Color(0.30, 0.30, 0.32),
]

## Ring colour under the feet, so what everyone is doing is readable at a glance
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

## Symbols shown above a resident's head. Six pixels of shape says what a panel
## would need a sentence for, and it is what lets the player read a whole street
## at a glance instead of clicking through it.
const STATE_SYMBOL := {
	GameEnums.CitizenState.EATING: "•••",
	GameEnums.CitizenState.SLEEPING: "z z",
	GameEnums.CitizenState.WORKING: "$",
	GameEnums.CitizenState.RELAXING: "~",
	GameEnums.CitizenState.SHOWERING: "≈",
	GameEnums.CitizenState.SOCIALIZING: "♥",
}


static func draw_citizen(canvas: CanvasItem, citizen: Citizen, font: Font, show_name: bool,
		selected: bool = false) -> void:
	var ground := IsoUtils.cell_to_world_f(citizen.position, citizen.floor_index)
	var accent: Color = STATE_COLORS.get(citizen.state, Color(0.8, 0.8, 0.8))
	var template := citizen.data()
	var skin: Color = template.placeholder_color if template != null else Color(0.92, 0.76, 0.62)
	var shirt: Color = SHIRTS[absi(citizen.id) % SHIRTS.size()]
	var hair: Color = HAIR[absi(citizen.id * 7 + 3) % HAIR.size()]

	canvas.draw_colored_polygon(_ellipse(ground, 9.0, 4.5), CITIZEN_SHADOW)
	# The state ring is the one piece of pure UI on the figure: colour on the
	# ground rather than on the shirt, so identity and activity never fight.
	canvas.draw_polyline(_ellipse(ground, 10.0, 5.0, 16) + PackedVector2Array([
			ground + Vector2(10.0, 0.0)]), accent, 1.5)
	if selected:
		canvas.draw_arc(ground, 15.0, 0.0, TAU, 24, SELECTION_RING, 2.0)

	if citizen.state == GameEnums.CitizenState.SLEEPING:
		_lying_figure(canvas, ground, skin, hair, shirt)
	else:
		_standing_figure(canvas, citizen, ground, skin, hair, shirt)

	var head_top := ground + Vector2(0.0, -_figure_height(citizen) - HEAD_RADIUS * 2.0)
	var symbol: String = STATE_SYMBOL.get(citizen.state, "")
	if symbol != "":
		Labels.draw(canvas, font, symbol, head_top + Vector2(0.0, -4.0),
				accent.lightened(0.35), 13, NAME_SHADOW)
	if show_name:
		Labels.draw(canvas, font, citizen.citizen_name, head_top + Vector2(0.0, -6.0),
				NAME_COLOR, 12, NAME_SHADOW)


## How tall the figure is right now — the anchor for anything drawn above it.
static func _figure_height(citizen: Citizen) -> float:
	if citizen.state == GameEnums.CitizenState.SLEEPING:
		return 8.0
	return BODY_HEIGHT + (0.0 if _is_seated(citizen) else LEG_HEIGHT)


## Seated when the model says they are standing *on* the thing they are using —
## the same flag the pathfinder uses to walk them onto a chair.
static func _is_seated(citizen: Citizen) -> bool:
	return citizen.target_interaction != null and citizen.target_interaction.stands_on_furniture \
			and citizen.state != GameEnums.CitizenState.WALKING


static func _standing_figure(canvas: CanvasItem, citizen: Citizen, ground: Vector2,
		skin: Color, hair: Color, shirt: Color) -> void:
	var seated := _is_seated(citizen)
	# A walking figure bobs and swings its legs; both come from the model's own
	# state, so the animation can never disagree with what is happening.
	var phase := 0.0
	var bob := 0.0
	if citizen.state == GameEnums.CitizenState.WALKING:
		phase = float(Time.get_ticks_msec()) * 0.012 + float(citizen.id)
		bob = absf(sin(phase)) * 1.6
	var hip := ground + Vector2(0.0, -LEG_HEIGHT - bob)
	if seated:
		# Knees forward, body dropped onto the seat.
		hip = ground + Vector2(0.0, -3.0)
		canvas.draw_colored_polygon(_quad(hip + Vector2(-4.5, -1.0), Vector2(9.0, 5.0)), TROUSERS)
	else:
		var swing := sin(phase) * 2.2
		canvas.draw_colored_polygon(_quad(ground + Vector2(-4.5 + swing, -LEG_HEIGHT - bob),
				Vector2(3.6, LEG_HEIGHT)), TROUSERS)
		canvas.draw_colored_polygon(_quad(ground + Vector2(0.9 - swing, -LEG_HEIGHT - bob),
				Vector2(3.6, LEG_HEIGHT)), TROUSERS.lightened(0.08))

	var shoulder := hip + Vector2(0.0, -BODY_HEIGHT)
	# Arms first, so the torso overlaps them and the silhouette stays clean.
	var arm_swing := -sin(phase) * 1.8
	canvas.draw_colored_polygon(_quad(shoulder + Vector2(-BODY_WIDTH * 0.5 - 1.6, 2.0 + arm_swing),
			Vector2(2.8, BODY_HEIGHT * 0.62)), shirt.darkened(0.18))
	canvas.draw_colored_polygon(_quad(shoulder + Vector2(BODY_WIDTH * 0.5 - 1.2, 2.0 - arm_swing),
			Vector2(2.8, BODY_HEIGHT * 0.62)), shirt.darkened(0.08))
	canvas.draw_colored_polygon(PackedVector2Array([
		hip + Vector2(-BODY_WIDTH * 0.42, 0.0),
		hip + Vector2(BODY_WIDTH * 0.42, 0.0),
		shoulder + Vector2(BODY_WIDTH * 0.5, 0.0),
		shoulder + Vector2(-BODY_WIDTH * 0.5, 0.0),
	]), shirt)

	var head := shoulder + Vector2(0.0, -HEAD_RADIUS * 0.9)
	canvas.draw_circle(head, HEAD_RADIUS, skin)
	# Hair as a cap over the top half of the head.
	canvas.draw_colored_polygon(_arc_cap(head, HEAD_RADIUS * 1.04, PI * 1.08, PI * 0.94), hair)
	if _faces_camera(citizen):
		canvas.draw_circle(head + Vector2(-2.0, 0.4), 0.8, EYE)
		canvas.draw_circle(head + Vector2(2.0, 0.4), 0.8, EYE)


## Which way they are heading, in screen terms. Walking towards the bottom of
## the screen means we see their face; walking away means we do not.
static func _faces_camera(citizen: Citizen) -> bool:
	if citizen.state != GameEnums.CitizenState.WALKING or citizen.path.is_empty():
		return true
	var step := Vector2(citizen.path[0]) - citizen.position
	return step.x + step.y >= -0.01


static func _lying_figure(canvas: CanvasItem, ground: Vector2, skin: Color, hair: Color,
		shirt: Color) -> void:
	var body := ground + Vector2(0.0, -6.0)
	canvas.draw_colored_polygon(_quad(body + Vector2(-11.0, -3.5), Vector2(18.0, 7.0)), shirt)
	canvas.draw_circle(body + Vector2(9.0, -1.0), HEAD_RADIUS * 0.92, skin)
	canvas.draw_colored_polygon(_arc_cap(body + Vector2(9.0, -1.0), HEAD_RADIUS,
			PI * 1.35, PI * 0.7), hair)


static func _quad(top_left: Vector2, size: Vector2) -> PackedVector2Array:
	return PackedVector2Array([
		top_left,
		top_left + Vector2(size.x, 0.0),
		top_left + size,
		top_left + Vector2(0.0, size.y),
	])


## A filled arc from `from_angle` spanning `span`, closed through the centre —
## a fringe of hair without needing a texture.
static func _arc_cap(center: Vector2, radius: float, from_angle: float, span: float,
		segments: int = 12) -> PackedVector2Array:
	var polygon := PackedVector2Array([center])
	for i in segments + 1:
		var angle := from_angle + span * float(i) / float(segments)
		polygon.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return polygon


static func _ellipse(center: Vector2, radius_x: float, radius_y: float, points: int = 12) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for i in points:
		var angle := TAU * float(i) / float(points)
		polygon.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	return polygon
