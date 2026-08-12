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
	results.append(_check_room_detection())
	results.append(_check_room_splitting())
	results.append(_check_data_layer())
	results.append(_check_database())
	results.append(_check_content_integrity())
	results.append(_check_pathfinding())
	results.append(_check_decision_scoring())
	results.append(_check_schedule())
	results.append(_check_skills())
	results.append(_check_variety())
	results.append(_check_city_events())
	results.append(_check_sound_bank())
	results.append(_check_art())
	results.append(_check_clock())
	results.append(_check_economy())
	results.append(_check_household_costs())
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


## The heart of Phase 2: walls in, rooms out. Checks the three cases that
## actually break in practice — an open shape, a sealed shape, and a door.
static func _check_room_detection() -> Result:
	var grid := WorldGrid.new(Vector2i(16, 16), 1)
	var from := Vector2i(2, 2)
	var to := Vector2i(5, 4)

	if not RoomDetector.detect(grid).is_empty():
		return Result.new("Room detection", false, "an empty map already reports rooms")

	var perimeter := WorldGrid.rect_perimeter_edges(from, to)
	for edge in perimeter:
		grid.set_edge(edge, GameEnums.EdgeType.WALL)

	var rooms := RoomDetector.detect(grid)
	if rooms.size() != 1:
		return Result.new("Room detection", false, "a closed rectangle produced %d rooms" % rooms.size())
	var room: Room = rooms[0]
	if room.area() != 12:
		return Result.new("Room detection", false, "4x3 room reported an area of %d" % room.area())
	if room.is_reachable():
		return Result.new("Room detection", false, "a room with no door reported itself as reachable")
	if room.anchor() != from:
		return Result.new("Room detection", false, "room anchor was %s, expected %s" % [room.anchor(), from])

	# A door keeps the room enclosed but makes it reachable — the distinction
	# the whole edge model exists for.
	grid.set_edge(WorldGrid.edge_key(Vector2i(3, 4), Vector2i.DOWN), GameEnums.EdgeType.DOOR)
	rooms = RoomDetector.detect(grid)
	if rooms.size() != 1 or not rooms[0].is_reachable():
		return Result.new("Room detection", false, "adding a door broke the room")

	# Knocking a hole in the wall opens it to the outdoors, so it stops being a
	# room at all.
	grid.set_edge(WorldGrid.edge_key(Vector2i(3, 2), Vector2i.UP), GameEnums.EdgeType.NONE)
	if not RoomDetector.detect(grid).is_empty():
		return Result.new("Room detection", false, "a wall was removed but the room survived")
	return Result.new("Room detection", true, "sealed shapes become rooms, doors keep them, holes dissolve them")


## Two rectangles sharing a border must be two rooms separated by ONE wall —
## the payoff of storing walls on edges instead of in cells.
static func _check_room_splitting() -> Result:
	var grid := WorldGrid.new(Vector2i(16, 16), 1)
	for edge in WorldGrid.rect_perimeter_edges(Vector2i(2, 2), Vector2i(5, 4)):
		grid.set_edge(edge, GameEnums.EdgeType.WALL)
	for edge in WorldGrid.rect_perimeter_edges(Vector2i(6, 2), Vector2i(8, 4)):
		grid.set_edge(edge, GameEnums.EdgeType.WALL)

	var shared := WorldGrid.edge_between(Vector2i(5, 3), Vector2i(6, 3))
	if grid.get_edge(shared) != GameEnums.EdgeType.WALL:
		return Result.new("Adjacent rooms", false, "the shared border is not a wall")

	var rooms := RoomDetector.detect(grid)
	if rooms.size() != 2:
		return Result.new("Adjacent rooms", false, "expected 2 rooms, got %d" % rooms.size())
	var areas := [rooms[0].area(), rooms[1].area()]
	areas.sort()
	if areas != [9, 12]:
		return Result.new("Adjacent rooms", false, "room areas were %s, expected [9, 12]" % str(areas))

	# One door in the shared wall connects both rooms at once.
	grid.set_edge(shared, GameEnums.EdgeType.DOOR)
	rooms = RoomDetector.detect(grid)
	if rooms.size() != 2:
		return Result.new("Adjacent rooms", false, "a door in the shared wall merged the rooms")
	if not (rooms[0].is_reachable() and rooms[1].is_reachable()):
		return Result.new("Adjacent rooms", false, "the shared door is not seen from both rooms")
	if not grid.can_walk_between(Vector2i(5, 3), Vector2i(6, 3)):
		return Result.new("Adjacent rooms", false, "citizens cannot walk through the shared door")
	return Result.new("Adjacent rooms", true, "one wall, two rooms, one door serving both")


## Room ids are regenerated on every rebuild, so the player's manual room type
## has to survive by anchor cell instead — including across a save and load.
## This is the one piece of Phase 2 state that is authored rather than derived.
static func check_room_type_persistence() -> Result:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return Result.new("Room type persistence", false, "no scene tree")

	var grid := WorldGrid.new(Vector2i(16, 16), 1)
	var registry := BuildingRegistry.new()
	registry.name = "SelfTestRegistry"
	tree.root.add_child(registry)
	# Handed the grid directly rather than through the bus, so the test cannot
	# disturb a world that may already be listening.
	registry._on_world_ready(grid)
	for edge in WorldGrid.rect_perimeter_edges(Vector2i(3, 3), Vector2i(6, 6)):
		grid.set_edge(edge, GameEnums.EdgeType.WALL)
	registry.rebuild()

	var failure := ""
	if registry.room_count() != 1:
		failure = "expected 1 room, got %d" % registry.room_count()
	else:
		var room: Room = registry.rooms.values()[0]
		registry.set_room_type(room.id, GameEnums.RoomType.BEDROOM)
		var saved: Dictionary = registry.save_data()

		registry.rebuild()
		var rebuilt: Room = registry.rooms.values()[0]
		if rebuilt.room_type != GameEnums.RoomType.BEDROOM:
			failure = "the room type was lost when rooms were rebuilt"
		elif registry.room_at(Vector2i(4, 4)) == null:
			failure = "cells inside the room do not point back at it"
		else:
			# A fresh registry loading the same payload must land on the same
			# room, which is what makes the save file map-independent.
			var reloaded := BuildingRegistry.new()
			reloaded.name = "SelfTestRegistryReloaded"
			tree.root.add_child(reloaded)
			reloaded._on_world_ready(grid)
			reloaded.load_data(saved)
			reloaded.rebuild()
			var loaded_room: Room = reloaded.rooms.values()[0]
			if loaded_room.room_type != GameEnums.RoomType.BEDROOM:
				failure = "the room type did not survive save and load"
			reloaded.queue_free()

	registry.queue_free()
	SaveManager.unregister("buildings")
	if failure != "":
		return Result.new("Room type persistence", false, failure)
	return Result.new("Room type persistence", true, "manual room types survive rebuilds and saves")


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
	var summary := "%d furniture, %d floors, %d jobs, %d citizens, %d schedules, %d skills, %d buildings, %d events" % [
			Database.furniture.size(), Database.floors.size(), Database.jobs.size(), Database.citizens.size(),
			Database.schedules.size(), Database.skills.size(), Database.buildings.size(), Database.events.size()]
	if errors.size() > 0:
		return Result.new("Content database", false, summary + " | " + ", ".join(errors))
	return Result.new("Content database", true, summary)


## Content is written by hand in .tres files, so it is worth checking that it
## actually parsed into what the code expects — especially the nested
## interaction resources, which are the part most likely to load as an empty
## array without anyone noticing until a citizen refuses to sleep.
static func _check_content_integrity() -> Result:
	var interaction_count := 0
	for template: FurnitureData in Database.furniture.values():
		if template.price <= 0:
			return Result.new("Content integrity", false, "%s has a non-positive price" % template.id)
		if template.size.x < 1 or template.size.y < 1:
			return Result.new("Content integrity", false, "%s has an empty footprint" % template.id)
		for interaction in template.interactions:
			if interaction == null:
				return Result.new("Content integrity", false, "%s has a null interaction" % template.id)
			if interaction.duration_minutes <= 0.0:
				return Result.new("Content integrity", false, "%s.%s takes no time" % [template.id, interaction.id])
			if interaction.need_effects.is_empty():
				return Result.new("Content integrity", false, "%s.%s changes nothing" % [template.id, interaction.id])
			interaction_count += 1
	for material: FloorData in Database.floors.values():
		if material.price_per_tile <= 0:
			return Result.new("Content integrity", false, "floor %s is free" % material.id)

	for template: FurnitureData in Database.furniture.values():
		for interaction in template.interactions:
			if interaction.required_skill_level > 0 and interaction.skill_id == &"":
				return Result.new("Content integrity", false,
						"%s.%s requires a level but names no skill" % [template.id, interaction.id])
			if interaction.skill_id != &"" and Database.skills.has(interaction.skill_id) == false:
				return Result.new("Content integrity", false,
						"%s.%s trains an unknown skill '%s'" % [template.id, interaction.id, interaction.skill_id])

	var bed := Database.get_furniture(&"bed_single")
	if bed == null or bed.find_interaction_for(GameEnums.NeedType.ENERGY) == null:
		return Result.new("Content integrity", false, "the bed does not offer a way to restore energy")
	var sleep := bed.find_interaction_for(GameEnums.NeedType.ENERGY)
	if sleep.state != GameEnums.CitizenState.SLEEPING:
		return Result.new("Content integrity", false, "sleeping in a bed does not put the citizen in the sleeping state")
	return Result.new("Content integrity", true, "%d templates, %d interactions, all well formed"
			% [Database.furniture.size() + Database.floors.size(), interaction_count])


## Pathfinding asks the grid one question and nothing else, so these three cases
## cover it: a straight walk, a sealed room, and the same room with a door.
static func _check_pathfinding() -> Result:
	var grid := WorldGrid.new(Vector2i(12, 12), 1)
	var path := Pathfinder.find_path(grid, Vector2i(0, 0), Vector2i(3, 0))
	if path.size() != 3 or path[path.size() - 1] != Vector2i(3, 0):
		return Result.new("Pathfinding", false, "a straight walk of 3 cells produced %d steps" % path.size())
	for i in path.size():
		var previous: Vector2i = Vector2i(0, 0) if i == 0 else path[i - 1]
		if IsoUtils.cell_distance(previous, path[i]) != 1:
			return Result.new("Pathfinding", false, "the path contains a diagonal or a jump")

	# Seal a room around (5,5): unreachable, no matter how close it looks.
	for edge in WorldGrid.rect_perimeter_edges(Vector2i(4, 4), Vector2i(6, 6)):
		grid.set_edge(edge, GameEnums.EdgeType.WALL)
	if not Pathfinder.find_path(grid, Vector2i(0, 0), Vector2i(5, 5)).is_empty():
		return Result.new("Pathfinding", false, "a route was found into a sealed room")

	# One door is enough to let a citizen in.
	grid.set_edge(WorldGrid.edge_key(Vector2i(5, 4), Vector2i.UP), GameEnums.EdgeType.DOOR)
	var through_door := Pathfinder.find_path(grid, Vector2i(0, 0), Vector2i(5, 5))
	if through_door.is_empty():
		return Result.new("Pathfinding", false, "a door did not open a route into the room")
	if not through_door.has(Vector2i(5, 3)):
		return Result.new("Pathfinding", false, "the route into the room does not pass through the door")

	# Furniture blocks in exactly the same way a wall does.
	grid.set_occupant(Vector2i(5, 3), 42)
	if not Pathfinder.find_path(grid, Vector2i(0, 0), Vector2i(5, 5)).is_empty():
		return Result.new("Pathfinding", false, "an object standing in the doorway did not block the route")
	return Result.new("Pathfinding", true, "walls block, doors open, objects block, no corner cutting")


## The scoring formula is the whole of Phase 5, so it is checked directly rather
## than by watching behaviour: urgency has to be convex, a full need has to be
## worthless, distance has to cost, and personality has to actually tip a choice.
static func _check_decision_scoring() -> Result:
	# Convex urgency: the gap between 10 and 30 must exceed the gap between
	# 30 and 50, otherwise nothing ever feels desperate.
	var low := DecisionMaker.urgency(10.0)
	var mid := DecisionMaker.urgency(30.0)
	var high := DecisionMaker.urgency(50.0)
	if not (low > mid and mid > high):
		return Result.new("Decision scoring", false, "urgency is not monotonic")
	if (low - mid) <= (mid - high):
		return Result.new("Decision scoring", false, "urgency curve is flat, not convex")

	var citizen := Citizen.new()
	citizen.data_id = &"adult"
	for type: int in GameEnums.NeedType.values():
		citizen.needs[type] = 80.0
	var snack := Database.get_furniture(&"fridge").interactions[0]

	# A need that is nearly full is not worth acting on.
	citizen.needs[GameEnums.NeedType.HUNGER] = 98.0
	var when_full := DecisionMaker.score_option(citizen, snack, 0.0)
	citizen.needs[GameEnums.NeedType.HUNGER] = 15.0
	var when_starving := DecisionMaker.score_option(citizen, snack, 0.0)
	if when_starving <= when_full * 5.0:
		return Result.new("Decision scoring", false,
				"starving scored %.3f against %.3f when full" % [when_starving, when_full])

	# Walking is dead time and has to lower the score.
	var nearby := DecisionMaker.score_option(citizen, snack, 0.0)
	var far_away := DecisionMaker.score_option(citizen, snack, 30.0)
	if far_away >= nearby:
		return Result.new("Decision scoring", false, "distance did not reduce the score")

	# Interrupting needs a clearly better option, not a marginally better one.
	if DecisionMaker.should_interrupt(1.0, 1.2):
		return Result.new("Decision scoring", false, "a marginally better option interrupted the citizen")
	if not DecisionMaker.should_interrupt(1.0, 5.0):
		return Result.new("Decision scoring", false, "a far better option failed to interrupt")

	# Personality: with identical needs, the NEAT resident must value a shower
	# more than the balanced one does.
	var shower := Database.get_furniture(&"shower").interactions[0]
	var neat := Citizen.new()
	neat.data_id = &"neat"
	for type: int in GameEnums.NeedType.values():
		neat.needs[type] = 40.0
	citizen.needs[GameEnums.NeedType.HUNGER] = 40.0
	for type: int in GameEnums.NeedType.values():
		citizen.needs[type] = 40.0
	var neat_score := DecisionMaker.score_option(neat, shower, 0.0)
	var plain_score := DecisionMaker.score_option(citizen, shower, 0.0)
	if neat_score <= plain_score:
		return Result.new("Decision scoring", false,
				"a neat resident valued washing at %.3f, no more than a balanced one at %.3f"
				% [neat_score, plain_score])
	return Result.new("Decision scoring", true,
			"urgency is convex, full needs score nothing, distance costs, personality tips the choice")


## A schedule is time-varying weights, so the things that can break are the
## clock arithmetic (blocks that wrap past midnight) and whether the weight
## actually reaches the decision.
static func _check_schedule() -> Result:
	var routine := Database.get_schedule(&"schedule_default")
	if routine == null:
		return Result.new("Daily routine", false, "the default schedule is missing")

	# Night runs 22:30 to 07:00, so it has to cover both sides of midnight.
	if routine.label_at(23.0) != "Night" or routine.label_at(3.0) != "Night":
		return Result.new("Daily routine", false, "the night block does not wrap past midnight")
	if routine.label_at(13.0) != "Lunch" or routine.label_at(21.0) != "Evening":
		return Result.new("Daily routine", false, "daytime blocks are misaligned")
	if routine.weight_for(GameEnums.NeedType.ENERGY, 23.0) <= 1.0:
		return Result.new("Daily routine", false, "sleep is not made urgent at night")
	if routine.weight_for(GameEnums.NeedType.ENERGY, 10.0) >= 1.0:
		return Result.new("Daily routine", false, "sleep is not discouraged during the day")
	if routine.weight_for(GameEnums.NeedType.HUNGER, 13.0) <= 1.0:
		return Result.new("Daily routine", false, "lunchtime does not favour eating")

	# The weight has to reach scoring: the same tired citizen, the same bed,
	# two different hours.
	var citizen := Citizen.new()
	citizen.data_id = &"adult"
	for type: int in GameEnums.NeedType.values():
		citizen.needs[type] = 80.0
	citizen.needs[GameEnums.NeedType.ENERGY] = 45.0
	var sleep := Database.get_furniture(&"bed_single").interactions[0]

	var saved := GameClock.total_minutes
	GameClock.total_minutes = 23.0 * 60.0
	GameClock._refresh_fields()
	var at_night := DecisionMaker.score_option(citizen, sleep, 0.0)
	GameClock.total_minutes = 10.0 * 60.0
	GameClock._refresh_fields()
	var at_ten := DecisionMaker.score_option(citizen, sleep, 0.0)
	GameClock.total_minutes = saved
	GameClock._refresh_fields()

	if at_night <= at_ten * 2.0:
		return Result.new("Daily routine", false,
				"going to bed scored %.2f at 23:00 against %.2f at 10:00" % [at_night, at_ten])
	return Result.new("Daily routine", true,
			"blocks wrap past midnight and bedtime scores %.1fx higher at 23:00 than at 10:00"
			% (at_night / maxf(at_ten, 0.001)))


## Progression: practice raises a level, a level makes the action better and
## faster, and some actions stay locked until it does. Without the last part a
## long game only gets faster, never wider.
static func _check_skills() -> Result:
	var cooking := Database.get_skill(&"cooking")
	if cooking == null:
		return Result.new("Skills", false, "the cooking skill is missing")

	var citizen := Citizen.new()
	citizen.data_id = &"adult"
	for type: int in GameEnums.NeedType.values():
		citizen.needs[type] = 50.0
	citizen.skills.clear()

	if citizen.skill_level(&"cooking") != 0:
		return Result.new("Skills", false, "a new resident already has levels")
	citizen.train(&"cooking", cooking.xp_for_level(3) + 1.0)
	var level := citizen.skill_level(&"cooking")
	if level != 3:
		return Result.new("Skills", false, "practice for level 3 produced level %d" % level)

	var feast: InteractionData = null
	var counter := Database.get_furniture(&"kitchen_counter")
	for interaction in counter.interactions:
		if interaction.id == &"cook_feast":
			feast = interaction
	if feast == null:
		return Result.new("Skills", false, "the skilled cooking option is missing")

	# Locked below the required level, available at it.
	var novice := Citizen.new()
	novice.data_id = &"adult"
	novice.skills.clear()
	if novice.can_perform(feast):
		return Result.new("Skills", false, "a beginner can cook the advanced meal")
	if not citizen.can_perform(feast):
		return Result.new("Skills", false, "a level 3 cook still cannot cook the advanced meal")

	# Better and faster.
	if citizen.skill_effect_multiplier(feast) <= 1.0:
		return Result.new("Skills", false, "skill does not improve the result")
	if citizen.skill_speed_multiplier(feast) >= 1.0:
		return Result.new("Skills", false, "skill does not make the action quicker")

	# And it pays: an employer that names the skill pays more for it.
	var earner := Citizen.new()
	earner.data_id = &"adult"
	earner.skills.clear()
	var base_wage := earner.wage_per_minute()
	earner.train(&"fitness", Database.get_skill(&"fitness").xp_for_level(4) + 1.0)
	if earner.wage_per_minute() <= base_wage:
		return Result.new("Skills", false, "levels in the skill the job names did not raise wages")
	return Result.new("Skills", true,
			"practice levels up, unlocks options, improves and speeds them, and raises pay")


## Variety: the same action repeated is worth less, and the penalty fades. This
## is what stops a resident watching television all evening, every evening.
static func _check_variety() -> Result:
	var citizen := Citizen.new()
	citizen.data_id = &"adult"
	for type: int in GameEnums.NeedType.values():
		citizen.needs[type] = 40.0
	var tv := Database.get_furniture(&"tv").interactions[0]

	var fresh := DecisionMaker.score_option(citizen, tv, 0.0)
	citizen.boredom[tv.id] = 1.0
	var stale := DecisionMaker.score_option(citizen, tv, 0.0)
	if stale >= fresh * 0.85:
		return Result.new("Variety", false,
				"a stale action scored %.2f against %.2f fresh" % [stale, fresh])

	# The other half of the rule, and the one that was missing. Boredom is
	# meant to reorder preferences, never to veto: a resident who is bored of
	# the television must still watch it rather than stand in the middle of the
	# room. Measured over five days, the veto version cost 45% of all waking
	# time, so this is a regression test for a real, dull bug.
	var bored := Citizen.new()
	bored.data_id = &"adult"
	for type: int in GameEnums.NeedType.values():
		bored.needs[type] = 80.0
	bored.needs[GameEnums.NeedType.ENTERTAINMENT] = 10.0
	bored.boredom[tv.id] = 1.0
	var last_resort := DecisionMaker.score_option(bored, tv, 0.0)
	if last_resort <= DecisionMaker.MIN_SCORE:
		return Result.new("Variety", false,
				"bored of the only television, a resident would rather do nothing (%.2f vs %.2f)"
				% [last_resort, DecisionMaker.MIN_SCORE])

	# Doing something else lets the appetite come back.
	citizen._age_boredom(GameConstants.BOREDOM_RECOVERY_MINUTES * 0.6)
	var recovered := DecisionMaker.score_option(citizen, tv, 0.0)
	if recovered <= stale:
		return Result.new("Variety", false, "staleness never fades")

	# Taste: the same option is worth more to someone who likes it.
	var fan := Citizen.new()
	fan.data_id = &"lazy"
	for type: int in GameEnums.NeedType.values():
		fan.needs[type] = 40.0
	var plain := Citizen.new()
	plain.data_id = &"social"
	for type: int in GameEnums.NeedType.values():
		plain.needs[type] = 40.0
	if fan.affinity(tv) <= plain.affinity(tv):
		return Result.new("Variety", false, "personal taste does not change how appealing an action is")
	return Result.new("Variety", true,
			"repetition loses %d%% of its value, still beats doing nothing when a need is urgent, recovers, and taste differs per resident"
			% roundi((1.0 - stale / maxf(fresh, 0.001)) * 100.0))


## Events are weights, not scripts, so what has to hold is that the weight
## reaches the decision, the money moves once, and the whole thing expires.
static func _check_city_events() -> Result:
	if Database.events.is_empty():
		return Result.new("City events", false, "no events are defined")

	var festival := Database.get_event(&"street_festival")
	if festival == null:
		return Result.new("City events", false, "the street festival is missing")
	if float(festival.need_weights.get(GameEnums.NeedType.SOCIAL, 1.0)) <= 1.0:
		return Result.new("City events", false, "a festival does not make company matter more")

	var saved_minutes := GameClock.total_minutes
	var money_before := Economy.money
	var running_before := CityEvents.active.duplicate()
	CityEvents.active.clear()

	var failure := ""
	# The grant pays out exactly once, when it starts.
	if not CityEvents.start(&"city_grant"):
		failure = "an event refused to start"
	elif Economy.money <= money_before:
		failure = "a windfall event paid nothing"
	elif CityEvents.start(&"city_grant"):
		failure = "the same event started twice at once"
	else:
		CityEvents.stop(&"city_grant")
		# While a festival runs, the social need weighs more in scoring.
		var citizen := Citizen.new()
		citizen.data_id = &"adult"
		for type: int in GameEnums.NeedType.values():
			citizen.needs[type] = 45.0
		var bench := Database.get_furniture(&"dining_bench")
		var chat: InteractionData = bench.interactions[0]
		var normal := DecisionMaker.score_option(citizen, chat, 0.0)
		CityEvents.start(&"street_festival")
		var during := DecisionMaker.score_option(citizen, chat, 0.0)
		if during <= normal:
			failure = "a festival did not make socialising more attractive (%.2f vs %.2f)" % [during, normal]
		elif not is_equal_approx(CityEvents.need_weight(GameEnums.NeedType.SOCIAL),
				float(festival.need_weights[GameEnums.NeedType.SOCIAL])):
			failure = "the active event's weight is not reported"
		else:
			# It ends by itself once its hours are up.
			GameClock.total_minutes += festival.duration_hours * 60.0 + 1.0
			GameClock._refresh_fields()
			CityEvents._on_hour_passed(GameClock.hour)
			if CityEvents.is_running(&"street_festival"):
				failure = "the festival never ended"
			elif not is_equal_approx(CityEvents.need_weight(GameEnums.NeedType.SOCIAL), 1.0):
				failure = "an ended event still affects the city"

	CityEvents.active = running_before
	Economy.money = money_before
	GameClock.total_minutes = saved_minutes
	GameClock._refresh_fields()
	if failure != "":
		return Result.new("City events", false, failure)
	return Result.new("City events", true,
			"%d events; they pay out once, bend the city's priorities while they run, and expire"
			% Database.events.size())


## Whether a sprite *looks* right is a job for eyes (`--showroom`). What can be
## checked here is the part that silently breaks: that art exists for every
## content id, and that its size still matches the footprint it is drawn on.
##
## The width rule is the important one. A furniture sprite is placed by pinning
## its bottom corner to the footprint's bottom corner and stretching it across
## (width + depth) half-tiles, so a sprite authored one pixel too wide does not
## fail to load — it drifts, and every copy of that object sits slightly off its
## own floor. One multiplication catches that at build time.
static func _check_art() -> Result:
	var expected_wall := Vector2i(GameConstants.TILE_HW,
			GameConstants.TILE_HH + GameConstants.WALL_HEIGHT) * int(Art.SPRITE_SCALE)
	for type in [GameEnums.EdgeType.WALL, GameEnums.EdgeType.DOOR, GameEnums.EdgeType.WINDOW]:
		for axis in [GameEnums.EdgeAxis.HORIZONTAL, GameEnums.EdgeAxis.VERTICAL]:
			var texture := Art.wall_texture(type, axis)
			if texture == null:
				return Result.new("Art", false, "no sprite for edge type %d axis %d" % [type, axis])
			if texture.get_size() != Vector2(expected_wall):
				return Result.new("Art", false, "edge type %d axis %d is %s, expected %s"
						% [type, axis, texture.get_size(), expected_wall])

	for material: FloorData in Database.all_floors():
		if material.is_road:
			# A road has one tile per shape of junction, picked from the
			# neighbours, so there is no tile under the material's own name.
			for kind in ["x", "y", "junction", "plain"]:
				if Art.road_texture(kind) == null:
					return Result.new("Art", false, "no road tile for '%s'" % kind)
		elif Art.floor_texture(material.id) == null:
			return Result.new("Art", false, "no ground tile for '%s'" % material.id)
	for index in Art.CAR_COLORS:
		for coming in [true, false]:
			for along_x in [true, false]:
				if Art.car_texture(index, coming, along_x) == null:
					return Result.new("Art", false, "car %d is missing a view" % index)
	for index in Art.GRASS_VARIANTS:
		if Art.grass(Vector2i(index, 0)) == null:
			return Result.new("Art", false, "grass variant %d is missing" % index)

	var templates := Database.all_furniture()
	for template: FurnitureData in templates:
		for turned in [false, true]:
			var texture := Art.furniture_texture(template.id, turned)
			if texture == null:
				return Result.new("Art", false, "no sprite for '%s'%s"
						% [template.id, " (turned)" if turned else ""])
			var size := template.rotated_size(1 if turned else 0)
			var wanted := float(size.x + size.y) * GameConstants.TILE_HW * Art.SPRITE_SCALE
			if not is_equal_approx(float(texture.get_width()), wanted):
				return Result.new("Art", false, "'%s' is %d px wide, footprint %s needs %d"
						% [template.id, texture.get_width(), size, int(wanted)])
			# The placement rectangle must land on the footprint it belongs to.
			var rect := Art.furniture_rect(Vector2i(5, 7), size, texture)
			var polygon := Art.footprint_polygon(Vector2i(5, 7), size)
			if not is_equal_approx(rect.end.y, polygon[2].y) or not is_equal_approx(rect.position.x, polygon[3].x):
				return Result.new("Art", false, "'%s' does not sit on its own footprint" % template.id)

	return Result.new("Art", true,
			"%d objects, %d ground tiles and 6 wall pieces, each sized to the cells it covers"
			% [templates.size(), Database.all_floors().size() + Art.GRASS_VARIANTS])


## The sound effects are generated rather than loaded, so what has to hold is
## that every key produces a real, non-silent, correctly formatted stream.
static func _check_sound_bank() -> Result:
	var bank := Sfx.bank()
	if bank.is_empty():
		return Result.new("Sound effects", false, "the sound bank is empty")
	for key: StringName in bank:
		var stream: AudioStreamWAV = bank[key]
		if stream == null:
			return Result.new("Sound effects", false, "'%s' produced nothing" % key)
		if stream.data.size() < 512:
			return Result.new("Sound effects", false, "'%s' is too short to hear" % key)
		if stream.mix_rate != Sfx.SAMPLE_RATE or stream.format != AudioStreamWAV.FORMAT_16_BITS:
			return Result.new("Sound effects", false, "'%s' has the wrong format" % key)
		# Silence would pass every other check, so look for actual signal.
		var peak := 0
		for i in range(0, mini(stream.data.size(), 8192), 2):
			peak = maxi(peak, absi(stream.data.decode_s16(i)))
		if peak < 1000:
			return Result.new("Sound effects", false, "'%s' is silent" % key)
	return Result.new("Sound effects", true, "%d effects generated, all audible" % bank.size())


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


## Placement is where the grid, the templates and the rooms meet, so this is the
## check that catches a footprint, an occupancy or a rotation going wrong.
static func check_furniture_placement() -> Result:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return Result.new("Furniture placement", false, "no scene tree")

	var grid := WorldGrid.new(Vector2i(16, 16), 1)
	var registry := FurnitureRegistry.new()
	registry.name = "SelfTestFurniture"
	tree.root.add_child(registry)
	registry._on_world_ready(grid)

	var failure := ""
	var bed := registry.place(&"bed_single", Vector2i(2, 2))
	if bed == null:
		failure = "could not place a bed on empty ground"
	elif bed.cells() != [Vector2i(2, 2), Vector2i(2, 3)]:
		failure = "1x2 bed occupies %s" % str(bed.cells())
	elif grid.is_free(Vector2i(2, 3)):
		failure = "the bed did not mark its cells as occupied"
	elif registry.place(&"bed_single", Vector2i(2, 3)) != null:
		failure = "a second bed was placed on top of the first"
	elif registry.furniture_at(Vector2i(2, 3)) != bed:
		failure = "the world does not report the bed standing on its own cell"
	else:
		# Rotating swaps the footprint, which is the whole point of storing
		# rotation instead of two separate templates.
		var sofa := registry.place(&"sofa", Vector2i(6, 6), 1)
		if sofa == null or sofa.cells() != [Vector2i(6, 6), Vector2i(6, 7)]:
			failure = "a rotated 2x1 sofa did not become 1x2"
		else:
			# A wall through the middle of a footprint must block placement.
			grid.set_edge(WorldGrid.edge_between(Vector2i(9, 9), Vector2i(9, 10)), GameEnums.EdgeType.WALL)
			if registry.can_place(Database.get_furniture(&"bed_single"), Vector2i(9, 9), 0):
				failure = "a bed was allowed to straddle a wall"
			else:
				var found := registry.find_for_need(GameEnums.NeedType.ENERGY)
				if found.is_empty() or found[0]["furniture"] != bed:
					failure = "asking the world for something that restores energy did not find the bed"
				elif not registry.remove(bed.id) or not grid.is_free(Vector2i(2, 3)):
					failure = "removing the bed did not free its cells"
				else:
					# Full round-trip through JSON, as the save file does it.
					var payload: Variant = JSON.parse_string(JSON.stringify(registry.save_data()))
					registry.load_data(payload)
					if registry.count() != 1:
						failure = "expected 1 item after loading, got %d" % registry.count()
					elif registry.furniture_at(Vector2i(6, 7)) == null:
						failure = "the reloaded sofa is not standing where it was saved"

	registry.queue_free()
	SaveManager.unregister("furniture")
	if failure != "":
		return Result.new("Furniture placement", false, failure)
	return Result.new("Furniture placement", true, "footprints, rotation, occupancy, need lookup and saving all hold")


## The whole Phase 4 loop end to end: a hungry resident notices, finds something
## that fixes it without being told what a fridge is, walks there, uses it, and
## gets less hungry. Driven by direct ticks so it takes milliseconds instead of
## waiting for real time to pass.
static func check_citizen_life() -> Result:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return Result.new("Citizen life", false, "no scene tree")

	var host := Node.new()
	host.name = "SelfTestWorld"
	tree.root.add_child(host)
	var grid := WorldGrid.new(Vector2i(12, 12), 1)
	var furniture := FurnitureRegistry.new()
	furniture.name = "Furniture"
	host.add_child(furniture)
	furniture._on_world_ready(grid)
	var registry := CitizenRegistry.new()
	registry.name = "Citizens"
	host.add_child(registry)
	registry._on_world_ready(grid)

	var failure := ""
	var fridge := furniture.place(&"fridge", Vector2i(8, 4))
	var citizen := registry.spawn(Vector2i(2, 2), &"adult")
	if fridge == null:
		failure = "could not place the fridge"
	elif citizen == null:
		failure = "could not spawn a resident"
	else:
		citizen.needs[GameEnums.NeedType.HUNGER] = 8.0
		var hunger_before: float = citizen.need(GameEnums.NeedType.HUNGER)
		var walked := false
		var ate := false
		var reserved := false
		# 200 game minutes is far more than the walk plus a 10 minute snack.
		for i in 200:
			citizen.sim_tick(1.0, GameEnums.SimLOD.FULL)
			if citizen.state == GameEnums.CitizenState.WALKING:
				walked = true
			if citizen.state == GameEnums.CitizenState.EATING:
				ate = true
				reserved = fridge.users.has(citizen.id)
			if ate and citizen.state == GameEnums.CitizenState.IDLE:
				break

		if not walked:
			failure = "the resident never walked anywhere"
		elif not ate:
			failure = "the resident never reached the fridge"
		elif not reserved:
			failure = "the fridge was not claimed while it was in use"
		elif not fridge.users.is_empty():
			failure = "the fridge stayed claimed after the snack finished"
		elif citizen.need(GameEnums.NeedType.HUNGER) <= hunger_before:
			failure = "eating did not reduce hunger (%.1f -> %.1f)" % [
					hunger_before, citizen.need(GameEnums.NeedType.HUNGER)]
		elif IsoUtils.cell_distance(citizen.cell(), Vector2i(8, 4)) > 2:
			failure = "the resident ate from %s, too far from the fridge" % citizen.cell()
		else:
			# Needs and position survive a save; the current errand does not, by
			# design — everyone re-decides what to do after loading.
			var payload: Variant = JSON.parse_string(JSON.stringify(registry.save_data()))
			var hunger := citizen.need(GameEnums.NeedType.HUNGER)
			registry.load_data(payload)
			if registry.count() != 1:
				failure = "expected 1 resident after loading, got %d" % registry.count()
			else:
				var loaded: Citizen = registry.all()[0]
				if absf(loaded.need(GameEnums.NeedType.HUNGER) - hunger) > 0.01:
					failure = "hunger did not survive the save"
				elif loaded.citizen_name != citizen.citizen_name:
					failure = "the resident lost their name in the save"

	for citizen_id: int in registry.citizens.keys():
		registry.remove(citizen_id)
	host.queue_free()
	SaveManager.unregister("furniture")
	SaveManager.unregister("citizens")
	if failure != "":
		return Result.new("Citizen life", false, failure)
	return Result.new("Citizen life", true, "hungry -> finds food -> walks -> eats -> fed, and it all saves")


## Behaviour, not formula: with a fridge next door and a TV across the flat, a
## starving resident must go and eat — and then, once fed, must stop choosing
## food. This is the case Phase 4 got wrong whenever two needs were both low.
static func check_priorities() -> Result:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return Result.new("Citizen priorities", false, "no scene tree")

	var host := Node.new()
	host.name = "SelfTestPriorities"
	tree.root.add_child(host)
	var grid := WorldGrid.new(Vector2i(24, 24), 1)
	var furniture := FurnitureRegistry.new()
	furniture.name = "Furniture"
	host.add_child(furniture)
	furniture._on_world_ready(grid)
	var registry := CitizenRegistry.new()
	registry.name = "Citizens"
	host.add_child(registry)
	registry._on_world_ready(grid)

	var failure := ""
	# Food two cells away, entertainment right next door.
	furniture.place(&"fridge", Vector2i(6, 4))
	furniture.place(&"tv", Vector2i(4, 5))
	var citizen := registry.spawn(Vector2i(4, 4), &"adult")
	if citizen == null:
		failure = "could not spawn a resident"
	else:
		citizen.needs[GameEnums.NeedType.HUNGER] = 8.0
		citizen.needs[GameEnums.NeedType.ENTERTAINMENT] = 35.0
		for i in 60:
			citizen.sim_tick(1.0, GameEnums.SimLOD.FULL)
			if citizen.state != GameEnums.CitizenState.IDLE and citizen.state != GameEnums.CitizenState.WALKING:
				break
		if citizen.state != GameEnums.CitizenState.EATING:
			failure = "a starving resident chose %s over food" % citizen.state_name()
		elif not citizen.current_reason.contains("hunger"):
			failure = "the resident cannot explain why it is eating ('%s')" % citizen.current_reason
		else:
			# Now full and bored: the same world must produce a different choice.
			citizen.needs[GameEnums.NeedType.HUNGER] = 95.0
			citizen.needs[GameEnums.NeedType.ENTERTAINMENT] = 10.0
			var switched := false
			for i in 200:
				citizen.sim_tick(1.0, GameEnums.SimLOD.FULL)
				if citizen.state == GameEnums.CitizenState.RELAXING:
					switched = true
					break
			if not switched:
				failure = "a fed but bored resident never went to the TV (state %s)" % citizen.state_name()

	for citizen_id: int in registry.citizens.keys():
		registry.remove(citizen_id)
	host.queue_free()
	SaveManager.unregister("furniture")
	SaveManager.unregister("citizens")
	if failure != "":
		return Result.new("Citizen priorities", false, failure)
	return Result.new("Citizen priorities", true, "urgent need wins over the closer option, and the choice changes when it is met")


## Furniture you stand *on* — a bed, a chair, a sofa — marks its own cells as
## occupied, so the destination is by definition not walkable. This is the case
## that silently made every bed in the game unusable, and a citizen who cannot
## sleep is not obvious from a screenshot, so it gets its own check.
static func check_sitting_furniture() -> Result:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return Result.new("Using furniture you sit on", false, "no scene tree")

	var host := Node.new()
	host.name = "SelfTestSitting"
	tree.root.add_child(host)
	var grid := WorldGrid.new(Vector2i(16, 16), 1)
	var furniture := FurnitureRegistry.new()
	furniture.name = "Furniture"
	host.add_child(furniture)
	furniture._on_world_ready(grid)
	var registry := CitizenRegistry.new()
	registry.name = "Citizens"
	host.add_child(registry)
	registry._on_world_ready(grid)

	var failure := ""
	var bed := furniture.place(&"bed_single", Vector2i(3, 3))
	var citizen := registry.spawn(Vector2i(9, 9), &"adult")
	if bed == null or citizen == null:
		failure = "could not set up a bed and a resident"
	elif Pathfinder.find_path(grid, Vector2i(9, 9), Vector2i(3, 3), 0, true).is_empty():
		failure = "no route onto the bed even with the goal allowed to be occupied"
	else:
		# Exhausted, everything else fine: the only sensible choice is the bed.
		for type: int in GameEnums.NeedType.values():
			citizen.needs[type] = 85.0
		citizen.needs[GameEnums.NeedType.ENERGY] = 6.0
		var slept := false
		for i in 300:
			citizen.sim_tick(1.0, GameEnums.SimLOD.FULL)
			if citizen.state == GameEnums.CitizenState.SLEEPING:
				slept = true
				break
		if not slept:
			failure = "an exhausted resident never got into bed (state %s, %s)" % [
					citizen.state_name(), citizen.current_reason]
		elif not bed.cells().has(citizen.cell()):
			failure = "the resident is sleeping at %s, which is not on the bed" % citizen.cell()
		elif not bed.users.has(citizen.id):
			failure = "the bed is not marked as occupied while slept in"

	for citizen_id: int in registry.citizens.keys():
		registry.remove(citizen_id)
	host.queue_free()
	SaveManager.unregister("furniture")
	SaveManager.unregister("citizens")
	if failure != "":
		return Result.new("Using furniture you sit on", false, failure)
	return Result.new("Using furniture you sit on", true, "a tired resident walks onto the bed and sleeps in it")


## A job is modelled as a need that is only urgent during the hours JobData
## defines. This checks the whole chain: the shift makes work pressing, working
## pays by the minute, and off-shift hours make it irrelevant again.
static func check_working_day() -> Result:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return Result.new("Working day", false, "no scene tree")

	var host := Node.new()
	host.name = "SelfTestWork"
	tree.root.add_child(host)
	var grid := WorldGrid.new(Vector2i(16, 16), 1)
	var furniture := FurnitureRegistry.new()
	furniture.name = "Furniture"
	host.add_child(furniture)
	furniture._on_world_ready(grid)
	var registry := CitizenRegistry.new()
	registry.name = "Citizens"
	host.add_child(registry)
	registry._on_world_ready(grid)

	var saved_minutes := GameClock.total_minutes
	var failure := ""
	furniture.place(&"desk", Vector2i(6, 6))
	var citizen := registry.spawn(Vector2i(3, 3), &"adult")
	if citizen == null:
		failure = "could not spawn a resident"
	elif citizen.job() == null:
		failure = "the adult archetype has no job"
	else:
		# Monday, ten in the morning: squarely inside the 08:00-17:00 shift.
		GameClock.total_minutes = 10.0 * 60.0
		GameClock._refresh_fields()
		if not citizen.is_on_shift():
			failure = "10:00 on a Monday is not recognised as working hours"
		else:
			citizen.start_new_day()
			for type: int in GameEnums.NeedType.values():
				if type != GameEnums.NeedType.WORK:
					citizen.needs[type] = 85.0
			var money_before := Economy.money
			var worked := false
			for i in 200:
				citizen.sim_tick(1.0, GameEnums.SimLOD.FULL)
				if citizen.state == GameEnums.CitizenState.WORKING:
					worked = true
					break
			if not worked:
				failure = "a resident on shift never went to work (state %s, %s)" % [
						citizen.state_name(), citizen.current_reason]
			else:
				for i in 90:
					citizen.sim_tick(1.0, GameEnums.SimLOD.FULL)
				if citizen.earned_today <= 0:
					failure = "an hour and a half of work paid nothing"
				elif Economy.money <= money_before:
					failure = "wages never reached the balance"
				elif citizen.need(GameEnums.NeedType.WORK) <= 0.0:
					failure = "working did not reduce the work owed"
				else:
					# Two in the morning: the same citizen must not care at all.
					GameClock.total_minutes = 2.0 * 60.0
					GameClock._refresh_fields()
					if citizen.is_on_shift():
						failure = "02:00 counts as working hours"
					elif citizen.duty_weight(GameEnums.NeedType.WORK) >= 1.0:
						failure = "work is still pressing in the middle of the night"

	GameClock.total_minutes = saved_minutes
	GameClock._refresh_fields()
	for citizen_id: int in registry.citizens.keys():
		registry.remove(citizen_id)
	host.queue_free()
	SaveManager.unregister("furniture")
	SaveManager.unregister("citizens")
	if failure != "":
		return Result.new("Working day", false, failure)
	return Result.new("Working day", true, "on shift they work and get paid by the minute, at night they do not")


## Household costs are a recurring line rather than one-off charges, so the
## daily settlement has a single place to happen and the HUD can explain it.
static func _check_household_costs() -> Result:
	var before_upkeep := Economy.daily_upkeep()
	Economy.set_upkeep("selftest_house", 250)
	if Economy.daily_upkeep() != before_upkeep + 250:
		Economy.remove_owner("selftest_house")
		return Result.new("Household costs", false, "adding an upkeep line did not change the daily total")
	Economy.set_income("selftest_job", 400)
	var net := Economy.daily_income() - Economy.daily_upkeep()

	var money_before := Economy.money
	Economy._on_day_passed(0)
	var settled := Economy.money - money_before
	Economy.remove_owner("selftest_house")
	Economy.remove_owner("selftest_job")
	Economy.money = money_before

	if settled != net:
		return Result.new("Household costs", false,
				"the day settled %d, expected the net of %d" % [settled, net])
	return Result.new("Household costs", true, "upkeep and income settle once a day, netted")


## Plots, families and the rule that ties them together: everything inside a
## house belongs to it by position, and residents use their own home rather than
## whatever bed happens to be nearest.
static func check_neighbourhood() -> Result:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return Result.new("Neighbourhood", false, "no scene tree")

	var host := Node.new()
	host.name = "SelfTestNeighbourhood"
	tree.root.add_child(host)
	var grid := WorldGrid.new(Vector2i(32, 24), 1)
	var lots := BuildingLots.new()
	lots.name = "Lots"
	host.add_child(lots)
	lots._on_world_ready(grid)
	var furniture := FurnitureRegistry.new()
	furniture.name = "Furniture"
	host.add_child(furniture)
	furniture._on_world_ready(grid)
	var citizens := CitizenRegistry.new()
	citizens.name = "Citizens"
	host.add_child(citizens)
	citizens._on_world_ready(grid)
	var households := HouseholdRegistry.new()
	households.name = "Households"
	host.add_child(households)
	households._on_world_ready(grid)

	var failure := ""
	var first := lots.place(&"house_small", Vector2i(2, 2))
	var second := lots.place(&"house_small", Vector2i(12, 2))
	if first == null or second == null:
		failure = "could not place two plots"
	elif lots.place(&"house_small", Vector2i(4, 3)) != null:
		failure = "an overlapping plot was allowed"
	else:
		# Floors make the plots habitable; without one, move-in is refused.
		if households.move_in(first, 2) != null:
			failure = "a family moved into a bare plot with no floor"
		for cell in first.cells():
			grid.set_floor_material(cell, &"floor_wood")
		for cell in second.cells():
			grid.set_floor_material(cell, &"floor_wood")

		var bed_a := furniture.place(&"bed_single", Vector2i(3, 3))
		var bed_b := furniture.place(&"bed_single", Vector2i(13, 3))
		if failure == "":
			if bed_a == null or bed_b == null:
				failure = "could not furnish the two houses"
			elif bed_a.building_id != first.id or bed_b.building_id != second.id:
				failure = "furniture did not inherit the plot it stands on"
			else:
				var household := households.move_in(first, 2)
				if household == null or household.size() != 2:
					failure = "moving a family in failed"
				else:
					var resident: Citizen = citizens.citizens[household.member_ids[0]]
					var other: Citizen = citizens.citizens[household.member_ids[1]]
					if resident.citizen_name.split(" ")[-1] != other.citizen_name.split(" ")[-1]:
						failure = "housemates do not share a surname"
					elif resident.home_building_id != first.id:
						failure = "a resident does not know which house is theirs"
					elif first.household_id != household.id:
						failure = "the house does not know who lives in it"
					elif not resident.may_use(bed_a):
						failure = "a resident may not use their own bed"
					elif resident.may_use(bed_b):
						failure = "a resident may use the neighbours' bed"
					else:
						# A shop is open to everyone, unlike a home.
						var shop := lots.place(&"shop", Vector2i(2, 14))
						for cell in shop.cells():
							grid.set_floor_material(cell, &"floor_tile")
						var till := furniture.place(&"desk", Vector2i(3, 15))
						if till == null or not resident.may_use(till):
							failure = "a resident may not use a commercial building"
						else:
							# Full round-trip: plots and families both persist.
							var lot_payload: Variant = JSON.parse_string(JSON.stringify(lots.save_data()))
							var home_payload: Variant = JSON.parse_string(JSON.stringify(households.save_data()))
							lots.load_data(lot_payload)
							households.load_data(home_payload)
							if lots.count() != 3 or households.count() != 1:
								failure = "plots or families did not survive the save (%d plots, %d families)" % [
										lots.count(), households.count()]
							elif households.get_household(household.id).size() != 2:
								failure = "the reloaded family lost its members"

	for citizen_id: int in citizens.citizens.keys():
		citizens.remove(citizen_id)
	host.queue_free()
	SaveManager.unregister("furniture")
	SaveManager.unregister("citizens")
	SaveManager.unregister("lots")
	SaveManager.unregister("households")
	if failure != "":
		return Result.new("Neighbourhood", false, failure)
	return Result.new("Neighbourhood", true,
			"plots claim land, families move in and share a name, and nobody sleeps in the neighbours' bed")


## Relationships: symmetric by construction, built by time spent together, and
## strong enough to change what a resident chooses to do.
static func check_relationships() -> Result:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return Result.new("Relationships", false, "no scene tree")

	var host := Node.new()
	host.name = "SelfTestRelationships"
	tree.root.add_child(host)
	var grid := WorldGrid.new(Vector2i(16, 16), 1)
	var book := RelationshipRegistry.new()
	book.name = "Relationships"
	host.add_child(book)
	var furniture := FurnitureRegistry.new()
	furniture.name = "Furniture"
	host.add_child(furniture)
	furniture._on_world_ready(grid)
	var citizens := CitizenRegistry.new()
	citizens.name = "Citizens"
	host.add_child(citizens)
	citizens._on_world_ready(grid)

	var failure := ""
	# One fact per pair: writing it from either side reads back the same.
	book.set_value(1, 2, 30.0)
	if not is_equal_approx(book.get_value(2, 1), 30.0):
		failure = "a relationship is not symmetric"
	elif not is_equal_approx(book.adjust(1, 2, 1000.0), 100.0):
		failure = "a relationship is not clamped to +100"
	else:
		book.values.clear()
		var bench := furniture.place(&"dining_bench", Vector2i(5, 5))
		var first := citizens.spawn(Vector2i(5, 6), &"social")
		var second := citizens.spawn(Vector2i(6, 6), &"adult")
		if bench == null or first == null or second == null:
			failure = "could not set up two residents and something to sit on"
		else:
			for type: int in GameEnums.NeedType.values():
				first.needs[type] = 70.0
				second.needs[type] = 70.0
			first.needs[GameEnums.NeedType.SOCIAL] = 10.0
			second.needs[GameEnums.NeedType.SOCIAL] = 10.0

			var chat: InteractionData = bench.data().interactions[0]
			# Sitting down alone is worth less than joining somebody.
			var alone := DecisionMaker.score_option(first, chat, 0.0, bench)
			bench.users.append(second.id)
			var joined := DecisionMaker.score_option(first, chat, 0.0, bench)
			if joined <= alone:
				failure = "joining somebody scored no better than sitting alone (%.2f vs %.2f)" % [joined, alone]
			else:
				# And joining a friend is worth more than joining a stranger.
				book.set_value(first.id, second.id, 80.0)
				var with_friend := DecisionMaker.score_option(first, chat, 0.0, bench)
				bench.users.clear()
				if with_friend <= joined:
					failure = "company of a friend is worth no more than a stranger's"
				else:
					book.values.clear()
					# Time together builds the relationship from nothing.
					for i in 240:
						first.sim_tick(1.0, GameEnums.SimLOD.FULL)
						second.sim_tick(1.0, GameEnums.SimLOD.FULL)
					var value := book.get_value(first.id, second.id)
					if value <= 0.0:
						failure = "two residents spent four hours in one room and never met"
					elif book.describe(value) == "":
						failure = "a relationship has no description to show the player"
					else:
						var payload: Variant = JSON.parse_string(JSON.stringify(book.save_data()))
						book.values.clear()
						book.load_data(payload)
						if not is_equal_approx(book.get_value(first.id, second.id), value):
							failure = "relationships did not survive a save"

	var summary := ""
	if failure == "":
		summary = "symmetric, clamped, built by time together, and worth choosing company for"
	for citizen_id: int in citizens.citizens.keys():
		citizens.remove(citizen_id)
	host.queue_free()
	SaveManager.unregister("furniture")
	SaveManager.unregister("citizens")
	SaveManager.unregister("relationships")
	if failure != "":
		return Result.new("Relationships", false, failure)
	return Result.new("Relationships", true, summary)


## Ticks are delivered over several frames, so this one is checked after a short
## wait rather than inline, together with the checks that need to add nodes to a
## tree that is no longer busy building the boot scene. Returns null while the probe has not been given a
## chance to run yet.
static func check_scheduler(probe: ProbeAgent, expected_min_ticks: int) -> Result:
	if probe.ticks >= expected_min_ticks:
		return Result.new("Simulation scheduler", true,
				"%d ticks, %.1f game minutes, %d agent(s) registered" % [probe.ticks, probe.minutes, SimScheduler.agent_count()])
	return Result.new("Simulation scheduler", false,
			"expected at least %d ticks, got %d" % [expected_min_ticks, probe.ticks])
