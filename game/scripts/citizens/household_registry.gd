class_name HouseholdRegistry
extends Node

## Creates families and moves them into houses.
##
## Moving in is the moment the game becomes what it is meant to be: a plot stops
## being a floor plan and becomes somebody's home. Everything downstream keys off
## the two fields set here — the citizen's `home_building_id` and the building's
## `household_id` — including the rule that residents use their *own* bed.

## household id -> Household
var households: Dictionary = {}

var _citizens: CitizenRegistry
var _lots: BuildingLots
var _grid: WorldGrid
var _next_id: int = 1


func _ready() -> void:
	EventBus.world_ready.connect(_on_world_ready)
	EventBus.day_passed.connect(_on_day_passed)
	SaveManager.register("households", self)


func _on_world_ready(world: WorldGrid) -> void:
	_grid = world
	_citizens = get_parent().get_node_or_null("Citizens") as CitizenRegistry
	_lots = get_parent().get_node_or_null("Lots") as BuildingLots


## Moves a new family of `size` into `building`. Returns null when the building
## cannot take them, with the reason on the bus so the UI can explain.
func move_in(building: Building, size: int = 2, archetypes: Array = []) -> Household:
	if building == null or not building.is_residential():
		EventBus.build_rejected.emit("Only homes can take a household")
		return null
	if building.household_id != -1:
		EventBus.build_rejected.emit("Somebody already lives there")
		return null
	var spots := _free_cells_in(building)
	if spots.is_empty():
		EventBus.build_rejected.emit("There is nowhere to stand inside — build a floor plan first")
		return null

	var wanted := clampi(size, 1, mini(building.max_residents(), spots.size()))
	var household := Household.new()
	household.id = _next_id
	_next_id += 1
	household.home_building_id = building.id
	households[household.id] = household

	var pool: Array = archetypes if not archetypes.is_empty() else _default_archetypes()
	for i in wanted:
		var archetype: StringName = pool[i % pool.size()]
		var citizen := _citizens.spawn(spots[i % spots.size()], archetype)
		if citizen == null:
			continue
		# One family, one surname: the first member names the household.
		if household.family_name == "Household":
			household.family_name = citizen.citizen_name.split(" ")[-1]
		else:
			citizen.citizen_name = "%s %s" % [citizen.citizen_name.split(" ")[0], household.family_name]
		citizen.home_building_id = building.id
		citizen.household_id = household.id
		household.add_member(citizen.id)

	# People who move in together already know each other.
	var book := get_parent().get_node_or_null("Relationships") as RelationshipRegistry
	if book != null:
		book.introduce_household(household.member_ids)

	building.household_id = household.id
	var plot_name := building.display_name
	building.display_name = household.label()
	EventBus.notify("%s moved into %s (%d residents)" % [household.label(), plot_name, household.size()])
	EventBus.household_changed.emit(household.id)
	return household


func get_household(household_id: int) -> Household:
	var household: Household = households.get(household_id)
	return household


func household_of(citizen: Citizen) -> Household:
	return get_household(citizen.household_id) if citizen != null else null


func count() -> int:
	return households.size()


## Cells inside the plot a resident can actually stand on. A bare plot has none
## until the player builds a floor, which is why move-in is refused on one.
func _free_cells_in(building: Building) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if _grid == null:
		return result
	for cell in building.cells():
		if _grid.is_walkable(cell, building.floor_index, true):
			result.append(cell)
	return result


## A family of mixed temperaments is more interesting to watch than three copies
## of the same person, so the default mix spreads across the archetypes.
func _default_archetypes() -> Array:
	return [&"adult", &"social", &"neat", &"lazy"]


## Each day the household banks what its members earned.
func _on_day_passed(_day: int) -> void:
	if _citizens == null:
		return
	for household: Household in households.values():
		for citizen_id: int in household.member_ids:
			var citizen: Citizen = _citizens.citizens.get(citizen_id)
			if citizen != null:
				household.savings += citizen.earned_today


# --- Persistence ------------------------------------------------------------

func save_data() -> Dictionary:
	var entries: Array = []
	for household: Household in households.values():
		entries.append(household.save_data())
	return {"households": entries}


func load_data(data: Dictionary) -> void:
	households.clear()
	_next_id = 1
	for entry: Dictionary in (data.get("households", []) as Array):
		var household := Household.from_save(entry)
		households[household.id] = household
		_next_id = maxi(_next_id, household.id + 1)
