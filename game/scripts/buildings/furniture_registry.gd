class_name FurnitureRegistry
extends Node

## Owns every placed object and keeps the world grid's occupancy in step with
## it. The single authority for "what is standing here" and "may I put this
## here" — the build tool asks, it never writes occupancy itself.
##
## Unlike rooms, furniture is *authored* data: the player put it there, nothing
## can recompute it. So it is saved in full, and its ids are stable.

## furniture id -> Furniture
var items: Dictionary = {}

var _grid: WorldGrid
var _next_id: int = 1


func _ready() -> void:
	EventBus.world_ready.connect(_on_world_ready)
	EventBus.rooms_rebuilt.connect(_on_rooms_rebuilt)
	SaveManager.register("furniture", self)


func _on_world_ready(world: WorldGrid) -> void:
	_grid = world


# --- Placement rules --------------------------------------------------------

## Why an object may not be placed, or "" when it may. Returning the reason
## rather than a bool is what lets the UI explain itself.
func placement_error(template: FurnitureData, origin: Vector2i, rotation_steps: int, floor_index: int = 0) -> String:
	if _grid == null or template == null:
		return "No world"
	var extent := template.rotated_size(rotation_steps)
	var footprint: Array[Vector2i] = []
	for y in extent.y:
		for x in extent.x:
			footprint.append(origin + Vector2i(x, y))

	for cell in footprint:
		if not _grid.in_bounds(cell):
			return "Outside the map"
		if not _grid.is_free(cell, floor_index):
			return "Something is already there"

	# A multi-cell object may not straddle a wall: every cell of the footprint
	# has to be reachable from the first one without crossing a solid edge.
	for cell in footprint:
		if cell == origin:
			continue
		if not _reachable_within(origin, cell, footprint, floor_index):
			return "A wall runs through it"

	if template.requires_wall and not _touches_wall(footprint, floor_index):
		return "Must be placed against a wall"
	return ""


func can_place(template: FurnitureData, origin: Vector2i, rotation_steps: int, floor_index: int = 0) -> bool:
	return placement_error(template, origin, rotation_steps, floor_index) == ""


## Small flood fill restricted to the footprint — footprints are 1 to 4 cells,
## so this is cheaper than it looks.
func _reachable_within(from: Vector2i, to: Vector2i, allowed: Array[Vector2i], floor_index: int) -> bool:
	var visited := {from: true}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		if cell == to:
			return true
		for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var neighbor: Vector2i = cell + direction
			if visited.has(neighbor) or not allowed.has(neighbor):
				continue
			if _grid.is_edge_solid(WorldGrid.edge_key(cell, direction), floor_index):
				continue
			visited[neighbor] = true
			queue.append(neighbor)
	return false


func _touches_wall(footprint: Array[Vector2i], floor_index: int) -> bool:
	for cell in footprint:
		for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			if _grid.is_edge_solid(WorldGrid.edge_key(cell, direction), floor_index):
				return true
	return false


# --- Mutations --------------------------------------------------------------

func place(data_id: StringName, origin: Vector2i, rotation_steps: int = 0, floor_index: int = 0) -> Furniture:
	var template := Database.get_furniture(data_id)
	if not can_place(template, origin, rotation_steps, floor_index):
		return null

	var item := Furniture.new()
	item.id = _next_id
	_next_id += 1
	item.data_id = data_id
	item.origin = origin
	item.rotation_steps = rotation_steps
	item.floor_index = floor_index
	_register(item)
	EventBus.furniture_placed.emit(item)
	return item


func remove(furniture_id: int) -> bool:
	var item: Furniture = items.get(furniture_id)
	if item == null:
		return false
	for cell in item.cells():
		_grid.set_occupant(cell, -1, item.floor_index)
	items.erase(furniture_id)
	EventBus.furniture_removed.emit(furniture_id)
	return true


func furniture_at(cell: Vector2i, floor_index: int = 0) -> Furniture:
	if _grid == null:
		return null
	var data := _grid.get_cell(cell, floor_index)
	if data != null and data.occupant_id != -1:
		return items.get(data.occupant_id)
	# Non-blocking objects (a lamp) leave the cell free, so they need a scan.
	for item: Furniture in items.values():
		if item.floor_index == floor_index and item.cells().has(cell):
			return item
	return null


func in_room(room_id: int) -> Array[Furniture]:
	var result: Array[Furniture] = []
	for item: Furniture in items.values():
		if item.room_id == room_id:
			result.append(item)
	return result


## Every object in a room that can raise `need`, paired with the interaction
## that does it. This is the query the citizen AI will live on in Phase 5 — note
## that it never mentions a specific piece of furniture.
func find_for_need(need: int, room_id: int = -1) -> Array:
	var result: Array = []
	for item: Furniture in items.values():
		if room_id != -1 and item.room_id != room_id:
			continue
		var template := item.data()
		if template == null:
			continue
		var interaction := template.find_interaction_for(need)
		if interaction != null and item.is_free_for(interaction):
			result.append({"furniture": item, "interaction": interaction})
	return result


func count() -> int:
	return items.size()


func _register(item: Furniture) -> void:
	items[item.id] = item
	_next_id = maxi(_next_id, item.id + 1)
	if item.blocks_movement():
		for cell in item.cells():
			_grid.set_occupant(cell, item.id, item.floor_index)
	item.room_id = _grid.room_of(item.origin, item.floor_index)


## Rooms are rebuilt whenever a wall changes, which can move an object from
## "outdoors" into a freshly closed room, or the other way round.
func _on_rooms_rebuilt(_building_id: int, _rooms: Array) -> void:
	for item: Furniture in items.values():
		item.room_id = _grid.room_of(item.origin, item.floor_index)


# --- Persistence ------------------------------------------------------------

func save_data() -> Dictionary:
	var entries: Array = []
	for item: Furniture in items.values():
		entries.append(item.save_data())
	return {"items": entries}


func load_data(data: Dictionary) -> void:
	for furniture_id: int in items.keys():
		remove(furniture_id)
	items.clear()
	_next_id = 1
	for entry: Dictionary in (data.get("items", []) as Array):
		var item := Furniture.from_save(entry)
		if Database.get_furniture(item.data_id) == null:
			# Content was removed or renamed since the save; skip it rather than
			# crashing the load.
			continue
		_register(item)
		EventBus.furniture_placed.emit(item)
