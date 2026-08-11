class_name Citizen
extends SimAgent

## A resident (design doc §12–§16). Pure model: it has no node, no sprite and no
## `_process`. The renderer reads `position` and draws something there; the
## SimScheduler decides how often this thinks.
##
## The state machine is deliberately small (§13: "a normal state machine suits
## this better"):
##
##   IDLE ──pick a goal──> WALKING ──arrive──> using state ──done──> IDLE
##                            └── no route ───────────────────────────┘
##
## Phase 4 picks the goal by "lowest need first". Phase 5 replaces that one
## method with proper utility scoring (distance, priority, schedule, mood) —
## everything else here stays as it is.

## How far a need may fall before the citizen goes looking for a fix.
const SEEK_THRESHOLD := GameConstants.NEED_URGENT_THRESHOLD

var id: int = -1
var citizen_name: String = "Resident"
var data_id: StringName = &""

## Fractional cell position: the cell it stands in plus where inside it.
var position: Vector2 = Vector2.ZERO
var floor_index: int = 0

var state: int = GameEnums.CitizenState.IDLE
## NeedType -> 0..100.
var needs: Dictionary = {}

## Remaining cells to walk, nearest first.
var path: Array[Vector2i] = []
var target_furniture_id: int = -1
var target_interaction: InteractionData
var interaction_elapsed: float = 0.0

## Where this citizen lives. Set when a household moves in (Phase 8); until then
## it simply stays where it was spawned.
var home_room_id: int = -1

var _data: CitizenData
var _grid: WorldGrid
var _furniture: FurnitureRegistry
## Re-picking a goal every single tick would thrash; wait this many game minutes
## after a failure before trying again.
var _retry_in: float = 0.0


func setup(grid: WorldGrid, furniture: FurnitureRegistry, template: CitizenData) -> void:
	_grid = grid
	_furniture = furniture
	_data = template
	if needs.is_empty() and template != null:
		for need: int in GameEnums.NeedType.values():
			needs[need] = template.starting_need(need)


func data() -> CitizenData:
	if _data == null and data_id != &"":
		_data = Database.get_citizen(data_id)
	return _data


func cell() -> Vector2i:
	return Vector2i(roundi(position.x), roundi(position.y))


func get_sim_cell() -> Vector2i:
	return cell()


## Takes a plain int rather than the enum type: need values arrive from
## dictionaries and JSON, neither of which narrows back into an enum.
func need(type: int) -> float:
	return float(needs.get(type, 100.0))


func lowest_need() -> int:
	var worst: int = GameEnums.NeedType.HUNGER
	var worst_value := 1000.0
	for type: int in needs:
		var value: float = needs[type]
		if value < worst_value:
			worst_value = value
			worst = type
	return worst


func state_name() -> String:
	return String(GameEnums.CitizenState.keys()[state]).capitalize()


# --- Simulation -------------------------------------------------------------

func sim_tick(minutes: float, lod: GameEnums.SimLOD) -> void:
	_decay_needs(minutes)
	_retry_in = maxf(_retry_in - minutes, 0.0)

	match state:
		GameEnums.CitizenState.IDLE:
			_tick_idle()
		GameEnums.CitizenState.WALKING:
			_tick_walking(minutes, lod)
		_:
			_tick_interaction(minutes)


## Needs fall continuously, scaled by personality. Because the tick carries the
## elapsed game minutes rather than a fixed step, a citizen simulated once per
## hour ends up exactly as hungry as one simulated ten times a second.
func _decay_needs(minutes: float) -> void:
	var template := data()
	for type: int in needs:
		var per_hour: float = GameConstants.NEED_DECAY_PER_HOUR.get(type, 0.0)
		if template != null:
			per_hour *= template.decay_multiplier(type)
		var before: float = needs[type]
		var after := clampf(before - per_hour * minutes / 60.0, GameConstants.NEED_MIN, GameConstants.NEED_MAX)
		needs[type] = after
		if before > SEEK_THRESHOLD and after <= SEEK_THRESHOLD:
			EventBus.citizen_need_critical.emit(id, type, after)


func _tick_idle() -> void:
	if _retry_in > 0.0:
		return
	var goal := _choose_goal()
	if goal.is_empty():
		# Nothing worth doing right now; check again shortly instead of every
		# tick, so an empty house costs almost nothing.
		_retry_in = 20.0
		return
	_begin_walk(goal)


## Phase 4 goal selection: fix whatever is worst, using whatever object in the
## world offers it. Note that no furniture is named here — the citizen asks the
## world "what can raise my hunger?" and takes the closest answer.
func _choose_goal() -> Dictionary:
	if _furniture == null or _grid == null:
		return {}
	var worst := lowest_need()
	if need(worst) > SEEK_THRESHOLD:
		return {}
	var here := cell()
	var best := {}
	var best_length := 1 << 30
	for option: Dictionary in _furniture.find_for_need(worst):
		var item: Furniture = option["furniture"]
		var interaction: InteractionData = option["interaction"]
		var access := item.access_cells(interaction, _grid)
		if access.is_empty():
			continue
		if access.has(here):
			var no_walk: Array[Vector2i] = []
			return {"furniture": item, "interaction": interaction, "path": no_walk}
		var route := Pathfinder.find_path_to_any(_grid, here, access, floor_index)
		if route.is_empty():
			continue
		if route.size() < best_length:
			best_length = route.size()
			best = {"furniture": item, "interaction": interaction, "path": route}
	return best


func _begin_walk(goal: Dictionary) -> void:
	var item: Furniture = goal["furniture"]
	var interaction: InteractionData = goal["interaction"]
	# Claim the object before walking, so two citizens never head for one bed.
	if not item.is_free_for(interaction):
		_retry_in = 10.0
		return
	item.users.append(id)
	target_furniture_id = item.id
	target_interaction = interaction
	var route: Array[Vector2i] = goal["path"]
	path = route
	if path.is_empty():
		_start_interaction()
	else:
		_set_state(GameEnums.CitizenState.WALKING)


func _tick_walking(minutes: float, lod: GameEnums.SimLOD) -> void:
	if path.is_empty():
		_start_interaction()
		return
	# Far from the camera nobody can see the walk, so it is resolved instantly
	# and the citizen keeps its schedule without costing anything.
	if lod == GameEnums.SimLOD.ABSTRACT:
		position = Vector2(path[path.size() - 1])
		path.clear()
		_start_interaction()
		return

	var template := data()
	var speed := template.walk_speed if template != null else 1.6
	var budget := speed * minutes
	while budget > 0.0 and not path.is_empty():
		var next := Vector2(path[0])
		var step := next - position
		var distance := step.length()
		if distance <= budget:
			position = next
			path.remove_at(0)
			budget -= distance
		else:
			position += step / distance * budget
			budget = 0.0
	if path.is_empty():
		_start_interaction()


func _start_interaction() -> void:
	var item := _target()
	if item == null or target_interaction == null:
		_abort_goal()
		return
	interaction_elapsed = 0.0
	_set_state(target_interaction.state)
	EventBus.citizen_interaction_started.emit(id, item.id, target_interaction.display_name)


## Needs are paid out continuously rather than in a lump at the end, so an
## interrupted meal still fed the citizen for as long as it lasted.
func _tick_interaction(minutes: float) -> void:
	if target_interaction == null:
		_abort_goal()
		return
	interaction_elapsed += minutes
	for type: int in target_interaction.need_effects:
		var gain := target_interaction.rate_per_minute(type) * minutes
		needs[type] = clampf(need(type) + gain, GameConstants.NEED_MIN, GameConstants.NEED_MAX)
	if interaction_elapsed >= target_interaction.duration_minutes:
		_finish_interaction()


func _finish_interaction() -> void:
	var item := _target()
	if item != null:
		item.users.erase(id)
		if target_interaction.money_delta != 0:
			if target_interaction.money_delta > 0:
				Economy.earn(target_interaction.money_delta, "wages")
			else:
				Economy.try_spend(-target_interaction.money_delta, "spending")
		EventBus.citizen_interaction_finished.emit(id, item.id, target_interaction.display_name)
	target_furniture_id = -1
	target_interaction = null
	interaction_elapsed = 0.0
	_set_state(GameEnums.CitizenState.IDLE)


## Something the citizen was heading for stopped existing — a bed sold, a wall
## built across the route. Release the claim and think again in a moment.
func _abort_goal() -> void:
	var item := _target()
	if item != null:
		item.users.erase(id)
	target_furniture_id = -1
	target_interaction = null
	path.clear()
	_retry_in = 10.0
	_set_state(GameEnums.CitizenState.IDLE)


func _target() -> Furniture:
	if _furniture == null or target_furniture_id == -1:
		return null
	return _furniture.items.get(target_furniture_id)


func _set_state(new_state: int) -> void:
	if state == new_state:
		return
	state = new_state
	EventBus.citizen_state_changed.emit(id, state)


# --- Persistence ------------------------------------------------------------
# The citizen's own state is saved; what it happened to be walking towards is
# not. On load everyone stands still for a moment and then picks a new goal,
# which is both simpler and more robust than restoring a stale route.

func save_data() -> Dictionary:
	var stored_needs := {}
	for type: int in needs:
		stored_needs[str(type)] = needs[type]
	return {
		"id": id,
		"name": citizen_name,
		"data_id": String(data_id),
		"x": position.x,
		"y": position.y,
		"floor": floor_index,
		"home_room": home_room_id,
		"needs": stored_needs,
	}


static func from_save(entry: Dictionary) -> Citizen:
	var citizen := Citizen.new()
	citizen.id = int(entry.get("id", -1))
	citizen.citizen_name = String(entry.get("name", "Resident"))
	citizen.data_id = StringName(entry.get("data_id", ""))
	citizen.position = Vector2(float(entry.get("x", 0.0)), float(entry.get("y", 0.0)))
	citizen.floor_index = int(entry.get("floor", 0))
	citizen.home_room_id = int(entry.get("home_room", -1))
	var stored: Dictionary = entry.get("needs", {})
	for key: String in stored.keys():
		citizen.needs[int(key)] = float(stored[key])
	return citizen
