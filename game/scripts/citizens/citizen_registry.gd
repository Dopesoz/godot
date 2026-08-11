class_name CitizenRegistry
extends Node

## Spawns residents and keeps them registered with the simulation scheduler.
##
## Citizens are model objects, not nodes, so this is where they are created,
## handed the world they live in, and put on the tick list. Removing a citizen
## from the scheduler is the only "cleanup" they need.

## citizen id -> Citizen
var citizens: Dictionary = {}

var _grid: WorldGrid
var _furniture: FurnitureRegistry
var _next_id: int = 1


func _ready() -> void:
	EventBus.world_ready.connect(_on_world_ready)
	EventBus.day_passed.connect(_on_day_passed)
	SaveManager.register("citizens", self)


func _on_world_ready(world: WorldGrid) -> void:
	_grid = world
	_furniture = get_parent().get_node_or_null("Furniture") as FurnitureRegistry
	for citizen: Citizen in citizens.values():
		citizen.setup(_grid, _furniture, Database.get_citizen(citizen.data_id))


## Puts a new resident on the map. Returns null when the cell cannot hold one.
func spawn(cell: Vector2i, data_id: StringName = &"adult", floor_index: int = 0) -> Citizen:
	if _grid == null or not _grid.is_walkable(cell, floor_index):
		return null
	var template := Database.get_citizen(data_id)
	var citizen := Citizen.new()
	citizen.id = _next_id
	_next_id += 1
	citizen.data_id = data_id
	citizen.citizen_name = _random_name(template)
	citizen.position = Vector2(cell)
	citizen.floor_index = floor_index
	_add(citizen, template)
	# A new arrival owes today's shift like everyone else — without this they
	# would start with a day's work already behind them and idle until midnight.
	citizen.start_new_day()
	return citizen


## A new day: today's shift is owed again, and the city pays for its residents.
func _on_day_passed(_day: int) -> void:
	for citizen: Citizen in citizens.values():
		citizen.start_new_day()
	_refresh_living_costs()


## Residents cost money simply by living here. Registered with the Economy as a
## recurring line rather than charged directly, so the daily settlement stays in
## one place and the HUD can show what it is made of.
func _refresh_living_costs() -> void:
	Economy.set_upkeep("residents", citizens.size() * GameConstants.LIVING_COST_PER_CITIZEN)


func remove(citizen_id: int) -> bool:
	var citizen: Citizen = citizens.get(citizen_id)
	if citizen == null:
		return false
	SimScheduler.unregister(citizen)
	citizens.erase(citizen_id)
	_refresh_living_costs()
	EventBus.citizen_removed.emit(citizen_id)
	return true


func citizen_at(cell: Vector2i, floor_index: int = 0) -> Citizen:
	for citizen: Citizen in citizens.values():
		if citizen.floor_index == floor_index and citizen.cell() == cell:
			return citizen
	return null


func count() -> int:
	return citizens.size()


func all() -> Array:
	return citizens.values()


func _add(citizen: Citizen, template: CitizenData) -> void:
	citizen.setup(_grid, _furniture, template)
	citizens[citizen.id] = citizen
	_next_id = maxi(_next_id, citizen.id + 1)
	SimScheduler.register(citizen)
	_refresh_living_costs()
	EventBus.citizen_spawned.emit(citizen)


## Names come from the template's pools, so a new archetype .tres brings its own
## naming without touching this file.
func _random_name(template: CitizenData) -> String:
	if template == null or template.first_names.is_empty():
		return "Resident %d" % _next_id
	var first: String = template.first_names[randi() % template.first_names.size()]
	if template.last_names.is_empty():
		return first
	var last: String = template.last_names[randi() % template.last_names.size()]
	return "%s %s" % [first, last]


# --- Persistence ------------------------------------------------------------

func save_data() -> Dictionary:
	var entries: Array = []
	for citizen: Citizen in citizens.values():
		entries.append(citizen.save_data())
	return {"citizens": entries}


func load_data(data: Dictionary) -> void:
	for citizen_id: int in citizens.keys():
		remove(citizen_id)
	citizens.clear()
	_next_id = 1
	for entry: Dictionary in (data.get("citizens", []) as Array):
		var citizen := Citizen.from_save(entry)
		_add(citizen, Database.get_citizen(citizen.data_id))
