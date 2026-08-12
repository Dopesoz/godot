class_name BuildingLots
extends Node

## Owns the plots on the map and stamps their id into the world grid.
##
## Membership is positional (see Building): placing a lot writes its id into
## every cell it covers, and anything standing on those cells belongs to it from
## then on. Removing a lot clears them again. Nothing else has to be told.

## building id -> Building
var buildings: Dictionary = {}

var _grid: WorldGrid
var _next_id: int = 1


func _ready() -> void:
	EventBus.world_ready.connect(_on_world_ready)
	SaveManager.register("lots", self)


func _on_world_ready(world: WorldGrid) -> void:
	_grid = world


## Why a plot cannot go here, or "" when it can. Plots may not overlap: two
## houses sharing cells would make "which building is this room in?" ambiguous,
## which is the one thing this design must never be.
func placement_error(template: BuildingData, origin: Vector2i) -> String:
	if _grid == null or template == null:
		return "No world"
	for cell in IsoUtils.cells_in_rect(origin, origin + template.size - Vector2i.ONE):
		if not _grid.in_bounds(cell):
			return "The plot does not fit on the map"
		if building_at(cell) != null:
			return "That land is already taken"
	return ""


func can_place(template: BuildingData, origin: Vector2i) -> bool:
	return placement_error(template, origin) == ""


func place(data_id: StringName, origin: Vector2i, floor_index: int = 0) -> Building:
	var template := Database.get_building(data_id)
	if not can_place(template, origin):
		return null
	var building := Building.new()
	building.id = _next_id
	_next_id += 1
	building.data_id = data_id
	building.origin = origin
	building.size = template.size
	building.floor_index = floor_index
	building.display_name = template.display_name
	_register(building)
	EventBus.building_placed.emit(building)
	return building


func remove(building_id: int) -> bool:
	var building: Building = buildings.get(building_id)
	if building == null:
		return false
	for cell in building.cells():
		_grid.set_building(cell, -1, building.floor_index)
	buildings.erase(building_id)
	_refresh_upkeep()
	EventBus.building_removed.emit(building_id)
	return true


func get_building(building_id: int) -> Building:
	var building: Building = buildings.get(building_id)
	return building


## Which plot covers this cell, read straight from the grid.
func building_at(cell: Vector2i, floor_index: int = 0) -> Building:
	if _grid == null:
		return null
	var data := _grid.get_cell(cell, floor_index)
	if data == null or data.building_id == -1:
		return null
	return get_building(data.building_id)


func residential() -> Array[Building]:
	var result: Array[Building] = []
	for building: Building in buildings.values():
		if building.is_residential():
			result.append(building)
	return result


## Plots with room for another household — what the move-in tool offers.
func vacant_homes() -> Array[Building]:
	var result: Array[Building] = []
	for building in residential():
		if building.household_id == -1:
			result.append(building)
	return result


func count() -> int:
	return buildings.size()


func _register(building: Building) -> void:
	buildings[building.id] = building
	_next_id = maxi(_next_id, building.id + 1)
	for cell in building.cells():
		_grid.set_building(cell, building.id, building.floor_index)
	_refresh_upkeep()


## Plots cost money to hold, whether or not anyone lives in them.
func _refresh_upkeep() -> void:
	var total := 0
	for building: Building in buildings.values():
		var template := building.data()
		if template != null:
			total += template.upkeep_per_day
	Economy.set_upkeep("buildings", total)


# --- Persistence ------------------------------------------------------------

func save_data() -> Dictionary:
	var entries: Array = []
	for building: Building in buildings.values():
		entries.append(building.save_data())
	return {"buildings": entries}


func load_data(data: Dictionary) -> void:
	for building_id: int in buildings.keys():
		remove(building_id)
	buildings.clear()
	_next_id = 1
	for entry: Dictionary in (data.get("buildings", []) as Array):
		var building := Building.from_save(entry)
		if Database.get_building(building.data_id) == null:
			continue
		_register(building)
		EventBus.building_placed.emit(building)
