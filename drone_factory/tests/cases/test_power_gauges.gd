extends TestCase
## Шкалы выработки над энергетическими зданиями.

var world: GameWorld = null
var simulation: Simulation = null
var gauges: PowerGauges = null


func before_each() -> void:
	world = GameWorld.new()
	Engine.get_main_loop().root.add_child(world)
	world.new_game(2727)
	simulation = Simulation.new()
	Engine.get_main_loop().root.add_child(simulation)
	world.simulation = simulation
	simulation.add_system(PowerSystem.new())
	simulation.setup(world)
	gauges = world.power_gauges


func after_each() -> void:
	for node: Node in [simulation, world]:
		if is_instance_valid(node):
			node.free()
	world = null
	simulation = null
	gauges = null


func test_only_power_buildings_get_a_gauge() -> void:
	for def_id: StringName in BuildingDefs.all_ids():
		var expected: bool = (
			BuildingDefs.power_gen(def_id) > 0.0
			or BuildingDefs.kind(def_id) == BuildingDefs.Kind.ACCUMULATOR
		)
		check_eq(
			PowerGauges.is_gauged(def_id), expected,
			"шкала у %s не соответствует его роли в сети" % def_id
		)


func test_every_generator_is_covered() -> void:
	# Игрок просил цифру у каждого здания, которое даёт энергию, — значит
	# ни один генератор не должен остаться без шкалы.
	var generators: int = 0
	for def_id: StringName in BuildingDefs.all_ids():
		if BuildingDefs.power_gen(def_id) <= 0.0:
			continue
		generators += 1
		check(PowerGauges.is_gauged(def_id), "генератор %s без шкалы" % def_id)
	check(generators >= 4, "генераторов должно быть несколько, найдено %d" % generators)


func test_gauge_layer_exists_in_the_world() -> void:
	check(gauges != null, "слой шкал не создан")
	check(gauges.z_index > world.building_renderer.z_index, "шкалы должны быть поверх зданий")
