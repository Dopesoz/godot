extends Node2D

## Tints detected rooms and lights them after dark. The names are drawn by
## WorldLabels, which sits above the buildings — down here they ended up behind
## the walls they were naming.
##
## This is the visible proof that room detection works: draw a closed rectangle
## of walls and the space inside changes colour immediately. A room without a
## door is marked, because a sealed room is a build mistake, not a design.

const UNDEFINED_TINT := Color(0.55, 0.75, 1.0, 0.16)
const NO_DOOR_TINT := Color(1.0, 0.45, 0.4, 0.20)
const LABEL_COLOR := Color(1.0, 1.0, 1.0, 0.9)
const LABEL_SHADOW := Color(0.0, 0.0, 0.0, 0.6)
## Warm light poured into rooms after dark so interiors stay readable while the
## streets go blue. Same trick as the windows: bright enough to survive the
## world-wide multiply from DayNight.
const LAMP_LIGHT := Color(3.0, 2.1, 1.0, 0.40)

const LOT_OUTLINE := Color(1.0, 0.95, 0.75, 0.35)
const LOT_LABEL := Color(1.0, 0.96, 0.85, 0.85)

var _rooms: Array = []
var _font: Font
## Room tints and labels are build-time information, not scenery. Once the
## floors had real materials they started fighting them — a bedroom carpet does
## not need a purple wash over it — so they now appear only while the room tool
## is in the player's hand. A room with no door stays marked whatever the tool,
## because that is a mistake and not a preference.
var _tool: int = GameEnums.ToolMode.NONE


func _ready() -> void:
	_font = ThemeDB.fallback_font
	EventBus.tool_mode_changed.connect(_on_tool_mode_changed)
	EventBus.rooms_rebuilt.connect(_on_rooms_rebuilt)
	EventBus.room_type_changed.connect(_on_room_type_changed)
	EventBus.daylight_changed.connect(_on_daylight_changed)
	EventBus.building_placed.connect(_on_building_changed)
	EventBus.building_removed.connect(_on_building_changed)
	EventBus.household_changed.connect(_on_building_changed)


func _on_tool_mode_changed(mode: int) -> void:
	_tool = mode
	queue_redraw()


func _on_rooms_rebuilt(_building_id: int, rooms: Array) -> void:
	_rooms = rooms
	queue_redraw()


func _on_room_type_changed(_room_id: int, _room_type: int) -> void:
	queue_redraw()


func _on_daylight_changed(_amount: float) -> void:
	queue_redraw()


func _on_building_changed(_arg: Variant = null) -> void:
	queue_redraw()


func _draw() -> void:
	_draw_lots()
	var darkness := 1.0 - GameClock.get_daylight()
	var planning := _tool == GameEnums.ToolMode.ASSIGN_ROOM
	for room: Room in _rooms:
		var show_room := planning or not room.is_reachable()
		var tint := _tint_for(room)
		var light := LAMP_LIGHT
		light.a *= darkness
		for cell in room.cells:
			var polygon := IsoUtils.cell_polygon(cell, room.floor_index)
			if show_room:
				draw_colored_polygon(polygon, tint)
			if darkness > 0.05:
				draw_colored_polygon(polygon, light)



## Plot borders and the name of whoever lives there. With several houses on the
## map this is what turns "some walls" into "the Meyers' place".
func _draw_lots() -> void:
	var lots := get_parent().get_node_or_null("Lots") as BuildingLots
	if lots == null:
		return
	for building: Building in lots.buildings.values():
		var corners := PackedVector2Array()
		var half := Vector2(0.0, GameConstants.TILE_HH)
		corners.append(IsoUtils.cell_to_world(building.origin, building.floor_index) - half)
		corners.append(IsoUtils.cell_to_world(building.origin + Vector2i(building.size.x - 1, 0), building.floor_index)
				+ Vector2(GameConstants.TILE_HW, 0.0))
		corners.append(IsoUtils.cell_to_world(building.origin + building.size - Vector2i.ONE, building.floor_index) + half)
		corners.append(IsoUtils.cell_to_world(building.origin + Vector2i(0, building.size.y - 1), building.floor_index)
				- Vector2(GameConstants.TILE_HW, 0.0))
		draw_polyline(corners + PackedVector2Array([corners[0]]), LOT_OUTLINE, 2.0)


func _tint_for(room: Room) -> Color:
	if not room.is_reachable():
		return NO_DOOR_TINT
	var data := Database.get_room_type(room.room_type)
	if data != null:
		var color := data.default_floor_color
		return Color(color.r, color.g, color.b, 0.18)
	return UNDEFINED_TINT
