class_name Room
extends RefCounted

## An enclosed space (design doc §8). Not authored by the player directly — the
## player draws walls, and RoomDetector notices that a set of cells has become
## sealed off. Model-layer only: it holds cells and ids, never nodes.

var id: int = -1
## A GameEnums.RoomType value. Stored as int because it also arrives from JSON
## and from Dictionary lookups, neither of which narrows back into an enum type.
var room_type: int = GameEnums.RoomType.UNDEFINED
var floor_index: int = 0

## Every cell inside the room.
var cells: Array[Vector2i] = []
## Canonical edge keys on the room's boundary, split by what sits there.
var door_edges: Array[Vector3i] = []
var window_edges: Array[Vector3i] = []

## Filled in by later phases; kept here so the room stays the one place to ask
## "what is in this space?".
var furniture_ids: Array[int] = []
var citizen_ids: Array[int] = []


func area() -> int:
	return cells.size()


## Stable identity across rebuilds. Rooms are recomputed from scratch whenever a
## wall changes, so numeric ids are not stable — the top-left cell is, as long as
## the room keeps that corner. Used to remember the player's room type choice.
func anchor() -> Vector2i:
	var best := Vector2i(1 << 30, 1 << 30)
	for cell in cells:
		if cell.y < best.y or (cell.y == best.y and cell.x < best.x):
			best = cell
	return best


func anchor_key() -> String:
	var a := anchor()
	return "%d,%d,%d" % [a.x, a.y, floor_index]


func contains(cell: Vector2i) -> bool:
	return cells.has(cell)


## Average cell position, for placing a label over the room.
func center() -> Vector2:
	if cells.is_empty():
		return Vector2.ZERO
	var sum := Vector2.ZERO
	for cell in cells:
		sum += Vector2(cell)
	return sum / float(cells.size())


## A room with no door can never be used by a citizen. The build UI warns about
## it instead of silently producing a sealed box.
func is_reachable() -> bool:
	return not door_edges.is_empty()


func type_name() -> String:
	var data := Database.get_room_type(room_type)
	if data != null and data.display_name != "":
		return Loc.t(data.display_name)
	return Loc.t(String(GameEnums.RoomType.keys()[room_type]).capitalize().replace("_", " "))
