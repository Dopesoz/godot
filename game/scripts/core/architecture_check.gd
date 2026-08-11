class_name ArchitectureCheck
extends RefCounted

## Phase 0 self-test. Runs on boot and proves that every layer of the
## architecture is wired up before a single sprite exists:
##
##   services  -> the six autoloads are alive and talk through the EventBus
##   geometry  -> grid <-> pixel conversion round-trips
##   model     -> walls block, doors pass, the grid serialises and restores
##   data      -> GameData templates load and answer AI-style questions
##   time      -> the clock advances and fires boundary signals
##   economy   -> money is charged and refused
##   saving    -> a full save/load cycle works with no scene involved
##
## Keeping this as a real runtime check rather than a written promise means the
## next twelve phases have a regression test from day one.

class Result:
	var name: String
	var ok: bool
	var detail: String

	func _init(check_name: String, passed: bool, info: String = "") -> void:
		name = check_name
		ok = passed
		detail = info


## Probe used to verify that SimScheduler actually delivers ticks.
class ProbeAgent extends SimAgent:
	var ticks: int = 0
	var minutes: float = 0.0

	func sim_tick(elapsed: float, _lod: GameEnums.SimLOD) -> void:
		ticks += 1
		minutes += elapsed


static func run_all() -> Array[Result]:
	var results: Array[Result] = []
	results.append(_check_autoloads())
	results.append(_check_iso_math())
	results.append(_check_edge_model())
	results.append(_check_walls_and_doors())
	results.append(_check_grid_serialisation())
	results.append(_check_data_layer())
	results.append(_check_database())
	results.append(_check_clock())
	results.append(_check_economy())
	results.append(_check_event_bus())
	results.append(_check_save_cycle())
	return results


static func _check_autoloads() -> Result:
	var missing: Array[String] = []
	var tree := Engine.get_main_loop() as SceneTree
	for name in ["EventBus", "Database", "GameClock", "SimScheduler", "Economy", "SaveManager"]:
		if tree == null or not tree.root.has_node(NodePath(name)):
			missing.append(name)
	if missing.is_empty():
		return Result.new("Autoload services", true, "6 services online")
	return Result.new("Autoload services", false, "missing: " + ", ".join(missing))


static func _check_iso_math() -> Result:
	for cell in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(7, 13), Vector2i(39, 39)]:
		var world := IsoUtils.cell_to_world(cell)
		var back := IsoUtils.world_to_cell(world)
		if back != cell:
			return Result.new("Isometric projection", false, "%s -> %s -> %s" % [cell, world, back])
	return Result.new("Isometric projection", true, "cell <-> pixel round-trips")


static func _check_edge_model() -> Result:
	var a := Vector2i(4, 4)
	var b := Vector2i(4, 5)
	var from_a := WorldGrid.edge_between(a, b)
	var from_b := WorldGrid.edge_between(b, a)
	if from_a != from_b:
		return Result.new("Shared wall edges", false, "%s != %s" % [from_a, from_b])
	var cells := WorldGrid.edge_cells(from_a)
	if not (cells.has(a) and cells.has(b)):
		return Result.new("Shared wall edges", false, "edge does not resolve back to its two cells")
	return Result.new("Shared wall edges", true, "one wall = one entry, seen from both sides")


static func _check_walls_and_doors() -> Result:
	var grid := WorldGrid.new(Vector2i(8, 8), 1)
	var a := Vector2i(2, 2)
	var b := Vector2i(2, 3)
	if not grid.can_walk_between(a, b):
		return Result.new("Walls and doors", false, "open ground is not walkable")
	grid.set_edge(WorldGrid.edge_between(a, b), GameEnums.EdgeType.WALL)
	if grid.can_walk_between(a, b):
		return Result.new("Walls and doors", false, "a wall did not block movement")
	grid.set_edge(WorldGrid.edge_between(a, b), GameEnums.EdgeType.DOOR)
	if not grid.can_walk_between(a, b):
		return Result.new("Walls and doors", false, "a door did not allow movement")
	if not grid.is_edge_solid(WorldGrid.edge_between(a, b)):
		return Result.new("Walls and doors", false, "a door must still enclose a room")
	return Result.new("Walls and doors", true, "wall blocks, door passes, door still encloses")


static func _check_grid_serialisation() -> Result:
	var grid := WorldGrid.new(Vector2i(12, 12), 1)
	grid.set_floor_material(Vector2i(3, 3), &"wood")
	grid.set_occupant(Vector2i(4, 3), 77)
	grid.set_room(Vector2i(3, 3), 5)
	grid.set_edge(WorldGrid.edge_key(Vector2i(3, 3), Vector2i.UP), GameEnums.EdgeType.WINDOW)

	# Round-trip through JSON, exactly as the save file does it.
	var json := JSON.stringify(grid.save_data())
	var parsed: Variant = JSON.parse_string(json)
	if typeof(parsed) != TYPE_DICTIONARY:
		return Result.new("World serialisation", false, "grid did not survive JSON encoding")
	var restored := WorldGrid.new(Vector2i(1, 1), 1)
	restored.load_data(parsed)

	var cell := restored.get_cell(Vector2i(3, 3))
	if cell == null or cell.floor_id != &"wood" or cell.room_id != 5:
		return Result.new("World serialisation", false, "cell data lost")
	if restored.get_cell(Vector2i(4, 3)).occupant_id != 77:
		return Result.new("World serialisation", false, "occupancy lost")
	if restored.get_edge(WorldGrid.edge_key(Vector2i(3, 3), Vector2i.UP)) != GameEnums.EdgeType.WINDOW:
		return Result.new("World serialisation", false, "edge data lost")
	return Result.new("World serialisation", true, "cells and edges survive a JSON round-trip")


static func _check_data_layer() -> Result:
	# Built in code rather than loaded from disk: this proves the template API
	# itself, independently of whether any content exists yet.
	var sleep := InteractionData.new()
	sleep.id = &"sleep"
	sleep.state = GameEnums.CitizenState.SLEEPING
	sleep.duration_minutes = 480.0
	sleep.need_effects = {GameEnums.NeedType.ENERGY: 90.0}

	var bed := FurnitureData.new()
	bed.id = &"bed_test"
	bed.category = FurnitureData.Category.SLEEPING
	bed.size = Vector2i(2, 1)
	var bed_interactions: Array[InteractionData] = [sleep]
	bed.interactions = bed_interactions

	if bed.find_interaction_for(GameEnums.NeedType.ENERGY) != sleep:
		return Result.new("Data-driven templates", false, "furniture cannot report what need it fixes")
	if bed.find_interaction_for(GameEnums.NeedType.HUNGER) != null:
		return Result.new("Data-driven templates", false, "furniture claims a need it does not satisfy")
	if bed.rotated_size(1) != Vector2i(1, 2):
		return Result.new("Data-driven templates", false, "rotation does not swap the footprint")
	if not is_equal_approx(sleep.rate_per_minute(GameEnums.NeedType.ENERGY), 90.0 / 480.0):
		return Result.new("Data-driven templates", false, "partial interaction payout is wrong")
	return Result.new("Data-driven templates", true, "AI can query furniture without knowing what a bed is")


static func _check_database() -> Result:
	if not Database.is_loaded():
		return Result.new("Content database", false, "database never finished loading")
	var errors := Database.get_errors()
	var summary := "%d furniture, %d jobs, %d citizens, %d buildings, %d room types" % [
		Database.furniture.size(), Database.jobs.size(), Database.citizens.size(),
		Database.buildings.size(), Database.room_types.size()]
	if errors.size() > 0:
		return Result.new("Content database", false, summary + " | " + ", ".join(errors))
	return Result.new("Content database", true, summary)


static func _check_clock() -> Result:
	var saved := GameClock.total_minutes
	var saved_speed := GameClock.speed_index
	GameClock.set_speed_index(0)
	GameClock.total_minutes = 0.0
	GameClock.advance(90.0)
	var ok := GameClock.hour == 1 and GameClock.minute == 30 and is_equal_approx(GameClock.hour_of_day(), 1.5)
	GameClock.total_minutes = 25.0 * 60.0
	GameClock._refresh_fields()
	var day_ok := GameClock.day == 1 and GameClock.hour == 1
	GameClock.total_minutes = saved
	GameClock._refresh_fields()
	GameClock.set_speed_index(saved_speed)
	if not ok:
		return Result.new("Game clock", false, "90 minutes did not become 01:30")
	if not day_ok:
		return Result.new("Game clock", false, "the day did not roll over after 24 hours")
	return Result.new("Game clock", true, "minutes, hours and days derive from one value")


static func _check_economy() -> Result:
	var before := Economy.money
	if not Economy.try_spend(10, "self-test"):
		return Result.new("Economy", false, "could not afford a 10 charge with %d in hand" % before)
	if Economy.money != before - 10:
		return Result.new("Economy", false, "balance did not change by the charged amount")
	if Economy.try_spend(before * 100 + 1_000_000, "self-test"):
		return Result.new("Economy", false, "an unaffordable purchase was allowed")
	Economy.earn(10, "self-test refund")
	if Economy.money != before:
		return Result.new("Economy", false, "self-test did not restore the balance")
	return Result.new("Economy", true, "charges apply, overspending is refused")


static func _check_event_bus() -> Result:
	var received := [0, 0]
	var on_money := func(_amount: int, delta: int) -> void:
		received[0] += 1
		received[1] = delta
	EventBus.money_changed.connect(on_money)
	Economy.earn(5, "self-test")
	Economy.try_spend(5, "self-test")
	EventBus.money_changed.disconnect(on_money)
	if received[0] != 2:
		return Result.new("Event bus", false, "expected 2 money signals, got %d" % received[0])
	return Result.new("Event bus", true, "systems communicate without holding references")


static func _check_save_cycle() -> Result:
	var slot := "__selftest"
	var money_before := Economy.money
	var minutes_before := GameClock.total_minutes

	if not SaveManager.save_game(slot):
		return Result.new("Save / load", false, "writing the save file failed")

	Economy.earn(4321, "self-test")
	GameClock.advance(777.0)

	if not SaveManager.load_game(slot):
		SaveManager.delete_slot(slot)
		return Result.new("Save / load", false, "reading the save file failed")

	var money_ok := Economy.money == money_before
	var time_ok := is_equal_approx(GameClock.total_minutes, minutes_before)
	SaveManager.delete_slot(slot)
	if not money_ok:
		return Result.new("Save / load", false, "money was %d, expected %d" % [Economy.money, money_before])
	if not time_ok:
		return Result.new("Save / load", false, "clock was not restored")
	return Result.new("Save / load", true, "state restored from JSON with no scene involved")


## Ticks are delivered over several frames, so this one is checked after a short
## wait rather than inline. Returns null while the probe has not been given a
## chance to run yet.
static func check_scheduler(probe: ProbeAgent, expected_min_ticks: int) -> Result:
	if probe.ticks >= expected_min_ticks:
		return Result.new("Simulation scheduler", true,
				"%d ticks, %.1f game minutes, %d agent(s) registered" % [probe.ticks, probe.minutes, SimScheduler.agent_count()])
	return Result.new("Simulation scheduler", false,
			"expected at least %d ticks, got %d" % [expected_min_ticks, probe.ticks])
