class_name WorldGrid
extends RefCounted

## The world model: cells and the edges between them. Pure data — no nodes, no
## sprites, no signals of its own beyond the EventBus notifications. The view
## layer reads this and draws it; the save file is a dump of it.
##
## THE CENTRAL IDEA: a wall is not a cell, it is a border between two cells.
##
##      (0,0)   |   (1,0)      the '|' is the VERTICAL edge stored at (1,0)
##      -------------          the '-' is the HORIZONTAL edge stored at (0,1)
##      (0,1)   |   (1,1)
##
## Every edge is stored once, in canonical form Vector3i(x, y, axis):
##   HORIZONTAL (x, y) is the northern border of cell (x, y)
##   VERTICAL   (x, y) is the western border of cell (x, y)
## The south border of (x, y) is therefore the same object as the north border
## of (x, y+1), which is exactly what we want: one wall, one entry, no chance of
## a room being airtight from one side and open from the other.
##
## Movement then needs no extra data structure. A citizen may step from cell A
## to neighbouring cell B when both are walkable and the single edge between
## them is absent or a door. Room detection is a flood fill using the same rule.

class Cell:
	## Flooring material id, &"" means bare ground (not part of a building).
	var floor_id: StringName = &""
	## Id of the furniture occupying this cell, -1 when free.
	var occupant_id: int = -1
	## Id of the room this cell belongs to, -1 when outdoors.
	var room_id: int = -1
	## Id of the building lot, -1 when outside any lot.
	var building_id: int = -1
	## Blocked by terrain (water, rock) — furniture uses occupant_id instead.
	var blocked: bool = false

	func is_free() -> bool:
		return occupant_id == -1 and not blocked


var size: Vector2i = GameConstants.MAP_SIZE
var floors: int = GameConstants.MAX_FLOORS

## One Dictionary per floor: Vector2i -> Cell. Sparse, because most of a 40x40
## map (and all of a 400x400 one) is untouched ground.
var _cells: Array[Dictionary] = []
## One Dictionary per floor: Vector3i canonical edge key -> GameEnums.EdgeType.
var _edges: Array[Dictionary] = []


func _init(grid_size: Vector2i = GameConstants.MAP_SIZE, floor_count: int = GameConstants.MAX_FLOORS) -> void:
	size = grid_size
	floors = maxi(floor_count, 1)
	for i in floors:
		_cells.append({})
		_edges.append({})


# --- Bounds -----------------------------------------------------------------

func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


func valid_floor(floor_index: int) -> bool:
	return floor_index >= 0 and floor_index < floors


# --- Cells ------------------------------------------------------------------

## Returns the stored cell, or null when nothing was ever written there.
## Callers that only read should use the `cell_*` helpers below instead.
func get_cell(cell: Vector2i, floor_index: int = 0) -> Cell:
	if not in_bounds(cell) or not valid_floor(floor_index):
		return null
	var data: Cell = _cells[floor_index].get(cell)
	return data


## Returns the cell, creating an empty one if needed. Only call when writing.
func get_or_create_cell(cell: Vector2i, floor_index: int = 0) -> Cell:
	if not in_bounds(cell) or not valid_floor(floor_index):
		return null
	var existing: Cell = _cells[floor_index].get(cell)
	if existing != null:
		return existing
	var created := Cell.new()
	_cells[floor_index][cell] = created
	return created


func set_floor_material(cell: Vector2i, floor_id: StringName, floor_index: int = 0) -> void:
	var data := get_or_create_cell(cell, floor_index)
	if data == null or data.floor_id == floor_id:
		return
	data.floor_id = floor_id
	EventBus.cell_changed.emit(cell, floor_index)


func set_occupant(cell: Vector2i, furniture_id: int, floor_index: int = 0) -> void:
	var data := get_or_create_cell(cell, floor_index)
	if data == null or data.occupant_id == furniture_id:
		return
	data.occupant_id = furniture_id
	EventBus.cell_changed.emit(cell, floor_index)


func set_room(cell: Vector2i, room_id: int, floor_index: int = 0) -> void:
	var data := get_or_create_cell(cell, floor_index)
	if data == null or data.room_id == room_id:
		return
	data.room_id = room_id
	EventBus.cell_changed.emit(cell, floor_index)


func is_free(cell: Vector2i, floor_index: int = 0) -> bool:
	if not in_bounds(cell) or not valid_floor(floor_index):
		return false
	var data: Cell = _cells[floor_index].get(cell)
	return data == null or data.is_free()


## Can a citizen stand here? Same as free, but also requires a built floor when
## `require_floor` is set (used for indoor-only pathing).
func is_walkable(cell: Vector2i, floor_index: int = 0, require_floor: bool = false) -> bool:
	if not is_free(cell, floor_index):
		return false
	if not require_floor:
		return true
	var data: Cell = _cells[floor_index].get(cell)
	return data != null and data.floor_id != &""


func room_of(cell: Vector2i, floor_index: int = 0) -> int:
	var data := get_cell(cell, floor_index)
	return -1 if data == null else data.room_id


# --- Edges ------------------------------------------------------------------

## Canonical key for the border of `cell` facing `direction`, where direction is
## one of Vector2i.UP / RIGHT / DOWN / LEFT.
static func edge_key(cell: Vector2i, direction: Vector2i) -> Vector3i:
	if direction == Vector2i.UP:
		return Vector3i(cell.x, cell.y, GameEnums.EdgeAxis.HORIZONTAL)
	if direction == Vector2i.DOWN:
		return Vector3i(cell.x, cell.y + 1, GameEnums.EdgeAxis.HORIZONTAL)
	if direction == Vector2i.LEFT:
		return Vector3i(cell.x, cell.y, GameEnums.EdgeAxis.VERTICAL)
	if direction == Vector2i.RIGHT:
		return Vector3i(cell.x + 1, cell.y, GameEnums.EdgeAxis.VERTICAL)
	push_error("WorldGrid.edge_key: %s is not an orthogonal direction" % direction)
	return Vector3i(cell.x, cell.y, GameEnums.EdgeAxis.HORIZONTAL)


## The single edge separating two orthogonally adjacent cells.
static func edge_between(a: Vector2i, b: Vector2i) -> Vector3i:
	return edge_key(a, b - a)


## The two cells an edge separates. The first is the one the edge is stored on.
static func edge_cells(edge: Vector3i) -> Array[Vector2i]:
	var cell := Vector2i(edge.x, edge.y)
	if edge.z == GameEnums.EdgeAxis.HORIZONTAL:
		return [cell, cell + Vector2i.UP]
	return [cell, cell + Vector2i.LEFT]


## Returns a GameEnums.EdgeType value. Typed as int because GDScript cannot
## implicitly narrow a Dictionary lookup back into an enum type.
func get_edge(edge: Vector3i, floor_index: int = 0) -> int:
	if not valid_floor(floor_index):
		return GameEnums.EdgeType.NONE
	var type: int = _edges[floor_index].get(edge, GameEnums.EdgeType.NONE)
	return type


func set_edge(edge: Vector3i, type: GameEnums.EdgeType, floor_index: int = 0) -> void:
	if not valid_floor(floor_index):
		return
	if get_edge(edge, floor_index) == type:
		return
	if type == GameEnums.EdgeType.NONE:
		_edges[floor_index].erase(edge)
	else:
		_edges[floor_index][edge] = type
	EventBus.edge_changed.emit(edge, floor_index)


func has_wall(cell: Vector2i, direction: Vector2i, floor_index: int = 0) -> bool:
	return get_edge(edge_key(cell, direction), floor_index) != GameEnums.EdgeType.NONE


## Doors let citizens through, walls and windows do not. Room detection uses the
## opposite rule for doors: a door still closes a room.
func is_edge_passable(edge: Vector3i, floor_index: int = 0) -> bool:
	var type: int = get_edge(edge, floor_index)
	return type == GameEnums.EdgeType.NONE or type == GameEnums.EdgeType.DOOR


## Does an edge close a room off? Doors and windows sit in a wall, so they all
## count as an enclosure for the flood fill.
func is_edge_solid(edge: Vector3i, floor_index: int = 0) -> bool:
	return get_edge(edge, floor_index) != GameEnums.EdgeType.NONE


## The one call navigation needs: may a citizen step from `from` to `to`?
func can_walk_between(from: Vector2i, to: Vector2i, floor_index: int = 0, require_floor: bool = false) -> bool:
	if IsoUtils.cell_distance(from, to) != 1:
		return false
	if not is_walkable(to, floor_index, require_floor):
		return false
	return is_edge_passable(edge_between(from, to), floor_index)


# --- Iteration --------------------------------------------------------------

func used_cells(floor_index: int = 0) -> Array:
	if not valid_floor(floor_index):
		return []
	return _cells[floor_index].keys()


func used_edges(floor_index: int = 0) -> Array:
	if not valid_floor(floor_index):
		return []
	return _edges[floor_index].keys()


func clear() -> void:
	for i in floors:
		_cells[i].clear()
		_edges[i].clear()


# --- Persistence ------------------------------------------------------------
# Vector2i/Vector3i keys are flattened to "x,y" strings because JSON keys must
# be strings. Only touched cells and edges are written, so an empty map costs a
# few bytes.

func save_data() -> Dictionary:
	var floor_payloads: Array = []
	for i in floors:
		var cells := {}
		for key: Vector2i in _cells[i].keys():
			var data: Cell = _cells[i][key]
			cells["%d,%d" % [key.x, key.y]] = {
				"f": String(data.floor_id),
				"o": data.occupant_id,
				"r": data.room_id,
				"b": data.building_id,
				"x": data.blocked,
			}
		var edges := {}
		for key: Vector3i in _edges[i].keys():
			edges["%d,%d,%d" % [key.x, key.y, key.z]] = int(_edges[i][key])
		floor_payloads.append({"cells": cells, "edges": edges})
	return {"size_x": size.x, "size_y": size.y, "floors": floors, "levels": floor_payloads}


func load_data(data: Dictionary) -> void:
	size = Vector2i(int(data.get("size_x", GameConstants.MAP_SIZE.x)), int(data.get("size_y", GameConstants.MAP_SIZE.y)))
	floors = maxi(int(data.get("floors", 1)), 1)
	_cells.clear()
	_edges.clear()
	for i in floors:
		_cells.append({})
		_edges.append({})

	var levels: Array = data.get("levels", [])
	for i in mini(levels.size(), floors):
		var level: Dictionary = levels[i]
		for key: String in (level.get("cells", {}) as Dictionary).keys():
			var parts := key.split(",")
			if parts.size() != 2:
				continue
			var entry: Dictionary = level["cells"][key]
			var cell := Cell.new()
			cell.floor_id = StringName(entry.get("f", ""))
			cell.occupant_id = int(entry.get("o", -1))
			cell.room_id = int(entry.get("r", -1))
			cell.building_id = int(entry.get("b", -1))
			cell.blocked = bool(entry.get("x", false))
			_cells[i][Vector2i(int(parts[0]), int(parts[1]))] = cell
		for key: String in (level.get("edges", {}) as Dictionary).keys():
			var parts := key.split(",")
			if parts.size() != 3:
				continue
			_edges[i][Vector3i(int(parts[0]), int(parts[1]), int(parts[2]))] = int(level["edges"][key])
