extends TestCase
## Порт дронов и модель дрона: предмет превращается в машину и обратно.

var world: GameWorld = null
var port: DronePort = null


func before_each() -> void:
	world = GameWorld.new()
	Engine.get_main_loop().root.add_child(world)
	world.new_game(6161)
	for i: int in world.grid.size * world.grid.size:
		world.grid.terrain[i] = TileTypes.Terrain.GRASS
	port = world.buildings.place(BuildingDefs.DRONE_PORT, world.start_cell + Vector2i(6, 6)) as DronePort


func after_each() -> void:
	if is_instance_valid(world):
		world.free()
	world = null
	port = null


func tick_port() -> void:
	port.tick(Constants.TICK_DELTA, {"grid": world.grid, "registry": world.buildings, "daylight": 1.0})


func test_port_is_specialised_class() -> void:
	check(port != null, "порт должен создаваться классом DronePort")
	check_eq(port.drone_count(), 0, "новый порт пуст")


func test_drone_items_become_drones() -> void:
	port.output.add(Items.DRONE, 3)
	tick_port()
	check_eq(port.drone_count(), 3, "предметы-дроны должны подниматься в воздух")
	check_eq(port.output.count(Items.DRONE), 0, "предметы должны сниматься со склада порта")


func test_drone_limit_is_respected() -> void:
	port.output.add(Items.DRONE, DronePort.MAX_DRONES + 4)
	tick_port()
	check_eq(port.drone_count(), DronePort.MAX_DRONES, "предел дронов на порт")
	check_eq(port.output.count(Items.DRONE), 4, "лишние дроны остаются предметами")


func test_port_without_power_does_not_work() -> void:
	port.output.add(Items.DRONE, 1)
	port.power_satisfaction = 0.0
	tick_port()
	check_eq(port.status, Building.Status.NO_POWER)
	check(not port.is_operational())


func test_powered_port_with_drones_works() -> void:
	port.output.add(Items.DRONE, 1)
	port.power_satisfaction = 1.0
	tick_port()
	check_eq(port.status, Building.Status.WORKING)
	check_eq(port.idle_drones().size(), 1)


func test_pack_drones_back_returns_items_and_cargo() -> void:
	port.output.add(Items.DRONE, 2)
	tick_port()
	port.drones[0].cargo_item = Items.IRON_PLATE
	port.drones[0].cargo_count = 7

	check_eq(port.pack_drones_back(), 2)
	check_eq(port.drone_count(), 0)
	check_eq(port.output.count(Items.DRONE), 2, "дроны должны вернуться предметами")
	check_eq(port.output.count(Items.IRON_PLATE), 7, "груз не должен пропасть")


func test_drone_flies_towards_target() -> void:
	var drone := Drone.new()
	drone.position = Vector2.ZERO
	drone.fly_to(Vector2(100, 0))
	var arrived: bool = drone.advance(0.5)
	check(not arrived, "за полсекунды дрон не долетит до цели в 100 px")
	check_almost(drone.position.x, Drone.SPEED * 0.5, 0.01)
	check_almost(drone.position.y, 0.0, 0.01)

	for i: int in 10:
		arrived = drone.advance(0.5)
	check(arrived, "дрон должен долететь")
	check_eq(drone.position, Vector2(100, 0), "прилетев, дрон встаёт ровно в цель")


func test_drone_does_not_overshoot() -> void:
	var drone := Drone.new()
	drone.position = Vector2.ZERO
	drone.fly_to(Vector2(2, 0))
	check(drone.advance(1.0), "цель ближе шага — должно засчитаться прибытие")
	check_eq(drone.position, Vector2(2, 0), "дрон не должен проскакивать цель")


func test_render_position_interpolates() -> void:
	var drone := Drone.new()
	drone.previous_position = Vector2(0, 0)
	drone.position = Vector2(10, 0)
	check_eq(drone.render_position(0.0), Vector2(0, 0))
	check_eq(drone.render_position(0.5), Vector2(5, 0))
	check_eq(drone.render_position(1.0), Vector2(10, 0))
	check_eq(drone.render_position(2.0), Vector2(10, 0), "альфа должна ограничиваться")


func test_heading_follows_movement() -> void:
	var drone := Drone.new()
	drone.previous_position = Vector2.ZERO
	drone.position = Vector2(10, 0)
	check_almost(drone.heading(), 0.0, 0.01, "полёт вправо — угол 0")
	drone.position = Vector2(0, 10)
	drone.previous_position = Vector2.ZERO
	check_almost(drone.heading(), PI / 2.0, 0.01, "полёт вниз — угол 90 градусов")


func test_drones_survive_save() -> void:
	port.output.add(Items.DRONE, 2)
	tick_port()
	port.drones[0].position = Vector2(1234, 5678)
	port.drones[0].cargo_item = Items.GEAR
	port.drones[0].cargo_count = 5
	port.drones[0].state = Drone.State.TO_TARGET

	var data: Array = world.buildings.serialize()
	var registry := BuildingRegistry.new(world.grid)
	world.buildings.clear()
	registry.deserialize(data)

	var restored: DronePort = registry.all()[0] as DronePort
	check_eq(restored.drone_count(), 2, "дроны должны сохраняться")
	check_eq(restored.drones[0].position, Vector2(1234, 5678))
	check_eq(restored.drones[0].cargo_item, Items.GEAR)
	check_eq(restored.drones[0].cargo_count, 5)
	check_eq(restored.drones[0].state, Drone.State.TO_TARGET)


func test_starting_base_has_flying_drones() -> void:
	world.buildings.clear()
	GameSetup.create_starting_base(world)
	var ports: Array[Building] = world.buildings.of_kind(BuildingDefs.Kind.DRONE_PORT)
	check(not ports.is_empty(), "в стартовой базе должен быть порт")
	check(
		(ports[0] as DronePort).drone_count() > 0,
		"стартовые дроны должны быть в воздухе, а не лежать на складе"
	)


func test_port_asks_for_drones_so_they_reach_it() -> void:
	# Именно этого не хватало: собранные дроны оседали на складе навсегда,
	# потому что порт ни о чём не просил, а логистика возит только по запросам.
	var free_slots: int = DronePort.MAX_DRONES - port.drone_count()
	check(free_slots > 0, "для проверки нужен порт с местом под дронов")
	var wanted: Dictionary = port.requests()
	check(wanted.has(Items.DRONE), "порт с пустыми местами обязан просить дронов")
	check_eq(int(wanted[Items.DRONE]), free_slots, "порт должен просить ровно недостающих")


func test_full_port_asks_for_nothing() -> void:
	port.output.add(Items.DRONE, DronePort.MAX_DRONES)
	port.tick(Constants.TICK_DELTA, {})
	check_eq(port.drone_count(), DronePort.MAX_DRONES, "порт должен принять всех дронов")
	check(not port.requests().has(Items.DRONE), "полный порт не должен просить ещё")


func test_pending_drones_are_not_requested_twice() -> void:
	# Дрон уже лежит в порту и вот-вот взлетит — просить на его место второго
	# нельзя, иначе склад опустеет впустую.
	var before: int = int(port.requests().get(Items.DRONE, 0))
	port.output.add(Items.DRONE, 1)
	check_eq(
		int(port.requests().get(Items.DRONE, 0)), before - 1,
		"дрон, ожидающий взлёта, должен считаться занятым местом"
	)
