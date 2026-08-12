extends Node2D

## Names of things, drawn over the world instead of into it.
##
## They used to be drawn by the layer that owns the thing being named — house
## names by the room overlay, which sits under the buildings. The result was
## "hop 4" and "ffice 5": the first letters were behind the walls of the very
## buildings they were labelling.
##
## So all world text that is not attached to a person lives here, in a node that
## draws after everything else. Room names come along for the ride, because a
## room name is just as easy to lose behind a wardrobe.

const LOT_LABEL := Color(1.0, 0.96, 0.85, 0.9)
const ROOM_LABEL := Color(1.0, 1.0, 1.0, 0.9)
const SHADOW := Color(0.0, 0.0, 0.0, 0.7)

var _font: Font
var _rooms: Array = []
var _tool: int = GameEnums.ToolMode.NONE


func _ready() -> void:
	_font = ThemeDB.fallback_font
	EventBus.tool_mode_changed.connect(_on_tool_mode_changed)
	EventBus.rooms_rebuilt.connect(_on_rooms_rebuilt)
	EventBus.room_type_changed.connect(_on_changed)
	EventBus.building_placed.connect(_on_changed)
	EventBus.building_removed.connect(_on_changed)
	EventBus.household_changed.connect(_on_changed)


func _on_tool_mode_changed(mode: int) -> void:
	_tool = mode
	queue_redraw()


func _on_rooms_rebuilt(_building_id: int, rooms: Array) -> void:
	_rooms = rooms
	queue_redraw()


func _on_changed(_a: Variant = null, _b: Variant = null) -> void:
	queue_redraw()


func _process(_delta: float) -> void:
	# The camera moves, and a label's position on screen — and therefore which
	# other label it collides with — moves with it.
	queue_redraw()


func _draw() -> void:
	var lots := get_parent().get_node_or_null("Lots") as BuildingLots
	if lots != null:
		for building: Building in lots.buildings.values():
			var anchor := IsoUtils.cell_to_world_f(building.centre(), building.floor_index) \
					- Vector2(0.0, float(building.size.y) * GameConstants.TILE_HH + 14.0)
			Labels.draw(self, _font, building.label(), anchor, LOT_LABEL, 15, SHADOW)

	if _tool != GameEnums.ToolMode.ASSIGN_ROOM:
		return
	for room: Room in _rooms:
		var text := "%s  %d %s" % [room.type_name(), room.area(), tr("m²")]
		if not room.is_reachable():
			text += "  (no door)"
		Labels.draw(self, _font, text,
				IsoUtils.cell_to_world_f(room.center(), room.floor_index), ROOM_LABEL, 14, SHADOW)
