class_name BuildingRegistry
extends Node

## Keeps the list of rooms in sync with the walls.
##
## Rooms are *derived* data: the walls are the truth, rooms are recomputed from
## them. That avoids the classic bug where a wall is deleted and a room object
## survives with stale cells. The only thing the player owns directly is the
## room's *type*, which is remembered by anchor cell across rebuilds.
##
## Rebuilds are deferred to the end of the frame, so dragging a wall rectangle
## that changes forty edges still runs the flood fill once.

## room id -> Room
var rooms: Dictionary = {}

## anchor key -> GameEnums.RoomType, the player's manual assignments.
var _type_by_anchor: Dictionary = {}

var _grid: WorldGrid
var _dirty: bool = false


func _ready() -> void:
	EventBus.world_ready.connect(_on_world_ready)
	EventBus.edge_changed.connect(_on_edge_changed)
	SaveManager.register("buildings", self)


func _on_world_ready(world: WorldGrid) -> void:
	_grid = world
	_dirty = true


func _on_edge_changed(_edge: Vector3i, _floor_index: int) -> void:
	_dirty = true


func _process(_delta: float) -> void:
	if _dirty:
		_dirty = false
		rebuild()


func rebuild() -> void:
	if _grid == null:
		return
	# Clear the old room ids first: cells that stopped being enclosed must not
	# keep pointing at a room that no longer exists.
	for cell: Vector2i in _grid.used_cells():
		_grid.set_room(cell, -1)

	rooms.clear()
	for room in RoomDetector.detect(_grid):
		room.room_type = int(_type_by_anchor.get(room.anchor_key(), GameEnums.RoomType.UNDEFINED))
		rooms[room.id] = room
		for cell in room.cells:
			_grid.set_room(cell, room.id)

	EventBus.rooms_rebuilt.emit(-1, rooms.values())


func get_room(room_id: int) -> Room:
	var room: Room = rooms.get(room_id)
	return room


func room_at(cell: Vector2i) -> Room:
	if _grid == null:
		return null
	return get_room(_grid.room_of(cell))


func set_room_type(room_id: int, room_type: GameEnums.RoomType) -> void:
	var room := get_room(room_id)
	if room == null:
		return
	room.room_type = room_type
	_type_by_anchor[room.anchor_key()] = room_type
	EventBus.room_type_changed.emit(room_id, room_type)


func room_count() -> int:
	return rooms.size()


# --- Persistence ------------------------------------------------------------
# Only the manual type assignments are saved. The rooms themselves are rebuilt
# from the walls on load, which means a save can never disagree with its map.

func save_data() -> Dictionary:
	return {"room_types": _type_by_anchor.duplicate()}


func load_data(data: Dictionary) -> void:
	# JSON gives every number back as a float, so the enum values are re-narrowed
	# here rather than leaking 3.0 into a match statement somewhere downstream.
	_type_by_anchor.clear()
	var stored: Dictionary = data.get("room_types", {})
	for key: String in stored.keys():
		_type_by_anchor[key] = int(stored[key])
	_dirty = true
