extends Node2D

## Tints detected rooms and labels them with their type and area.
##
## This is the visible proof that room detection works: draw a closed rectangle
## of walls and the space inside changes colour immediately. A room without a
## door is marked, because a sealed room is a build mistake, not a design.

const UNDEFINED_TINT := Color(0.55, 0.75, 1.0, 0.16)
const NO_DOOR_TINT := Color(1.0, 0.45, 0.4, 0.20)
const LABEL_COLOR := Color(1.0, 1.0, 1.0, 0.9)
const LABEL_SHADOW := Color(0.0, 0.0, 0.0, 0.6)

var _rooms: Array = []
var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font
	EventBus.rooms_rebuilt.connect(_on_rooms_rebuilt)
	EventBus.room_type_changed.connect(_on_room_type_changed)


func _on_rooms_rebuilt(_building_id: int, rooms: Array) -> void:
	_rooms = rooms
	queue_redraw()


func _on_room_type_changed(_room_id: int, _room_type: int) -> void:
	queue_redraw()


func _draw() -> void:
	for room: Room in _rooms:
		var tint := _tint_for(room)
		for cell in room.cells:
			draw_colored_polygon(IsoUtils.cell_polygon(cell, room.floor_index), tint)
		_draw_label(room)


func _tint_for(room: Room) -> Color:
	if not room.is_reachable():
		return NO_DOOR_TINT
	var data := Database.get_room_type(room.room_type)
	if data != null:
		var color := data.default_floor_color
		return Color(color.r, color.g, color.b, 0.18)
	return UNDEFINED_TINT


func _draw_label(room: Room) -> void:
	var text := "%s  %d m²" % [room.type_name(), room.area()]
	if not room.is_reachable():
		text += "  (no door)"
	var position := IsoUtils.cell_to_world_f(room.center(), room.floor_index)
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	var origin := position - Vector2(width * 0.5, 0.0)
	draw_string(_font, origin + Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, LABEL_SHADOW)
	draw_string(_font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, LABEL_COLOR)
