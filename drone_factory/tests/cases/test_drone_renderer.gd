extends TestCase
## Отрисовка флота: один MultiMesh на всех дронов, интерполяция между тиками.

var world: GameWorld = null
var simulation: Simulation = null
var port: DronePort = null


func before_each() -> void:
	world = GameWorld.new()
	Engine.get_main_loop().root.add_child(world)
	simulation = Simulation.new()
	Engine.get_main_loop().root.add_child(simulation)
	world.simulation = simulation
	world.new_game(3131)
	simulation.setup(world)
	for i: int in world.grid.size * world.grid.size:
		world.grid.terrain[i] = TileTypes.Terrain.GRASS

	port = world.buildings.place(BuildingDefs.DRONE_PORT, world.start_cell + Vector2i(5, 5)) as DronePort
	port.output.add(Items.DRONE, 3)
	port.tick(Constants.TICK_DELTA, {"grid": world.grid, "registry": world.buildings, "daylight": 1.0})


func after_each() -> void:
	if is_instance_valid(simulation):
		simulation.free()
	if is_instance_valid(world):
		world.free()
	world = null
	simulation = null
	port = null


func test_all_drones_share_one_multimesh() -> void:
	world.drone_renderer._process(0.016)
	check_eq(world.drone_renderer.visible_drones(), 3, "должны рисоваться все три дрона")
	check_eq(world.drone_renderer.multimesh.visible_instance_count, 3)
	check(world.drone_renderer.multimesh.instance_count >= 3, "буфер должен вмещать флот")


func test_capacity_grows_for_large_fleet() -> void:
	# Несколько портов: буфер обязан расшириться без потери дронов.
	for i: int in 4:
		var extra: DronePort = world.buildings.place(
			BuildingDefs.DRONE_PORT, world.start_cell + Vector2i(10 + i * 4, 5)
		) as DronePort
		extra.output.add(Items.DRONE, DronePort.MAX_DRONES)
		extra.tick(Constants.TICK_DELTA, {"grid": world.grid, "registry": world.buildings, "daylight": 1.0})

	world.drone_renderer._process(0.016)
	check_eq(world.drone_renderer.visible_drones(), 3 + 4 * DronePort.MAX_DRONES)
	check(
		world.drone_renderer.multimesh.instance_count >= world.drone_renderer.visible_drones(),
		"буфер не должен переполняться"
	)


func test_transform_follows_drone_position() -> void:
	var drone: Drone = port.drones[0]
	drone.previous_position = Vector2(100, 100)
	drone.position = Vector2(200, 100)
	var transform: Transform2D = DroneRenderer.instance_transform(drone, 1.0)
	check_eq(transform.origin, Vector2(200, 100), "без остатка времени дрон рисуется в новой точке")
	check_almost(transform.get_rotation(), 0.0, 0.01, "спрайт разворачивается по курсу")


func test_interpolation_uses_tick_alpha() -> void:
	var drone: Drone = port.drones[0]
	drone.previous_position = Vector2(0, 0)
	drone.position = Vector2(100, 0)
	# Половина логического тика прошла — дрон должен быть на полпути.
	simulation._accumulator = Constants.TICK_DELTA * 0.5
	check_almost(simulation.tick_alpha(), 0.5)
	var transform: Transform2D = DroneRenderer.instance_transform(drone, simulation.tick_alpha())
	check_almost(transform.origin.x, 50.0, 0.5, "полёт должен интерполироваться между тиками")
	# Полный тик и остаток больше тика дают одну и ту же точку.
	simulation._accumulator = Constants.TICK_DELTA * 2.0
	check_almost(simulation.tick_alpha(), 1.0, 0.001, "альфа должна ограничиваться единицей")


func test_cargo_is_visible_by_colour() -> void:
	port.drones[0].cargo_item = Items.COPPER_ORE
	port.drones[0].cargo_count = 5
	check_eq(
		DroneRenderer.instance_color(port.drones[0]),
		Items.color(Items.COPPER_ORE),
		"гружёный дрон подсвечивается цветом груза"
	)
	check_eq(DroneRenderer.instance_color(port.drones[1]), Color.WHITE, "порожний дрон не тонируется")


func test_removed_port_removes_drones_from_view() -> void:
	world.buildings.remove(port.id)
	world.drone_renderer._process(0.016)
	check_eq(world.drone_renderer.visible_drones(), 0, "снесённый порт не должен оставлять призраков")


func test_quad_uses_atlas_region() -> void:
	var mesh: ArrayMesh = world.drone_renderer.multimesh.mesh
	var arrays: Array = mesh.surface_get_arrays(0)
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var region: Rect2i = Art.region(ObjectArt.DRONE)
	var atlas_size := Vector2(Art.object_texture.get_width(), Art.object_texture.get_height())
	check_almost(uvs[0].x, float(region.position.x) / atlas_size.x, 0.001, "UV должны указывать на спрайт дрона")
	check_almost(uvs[2].y, float(region.end.y) / atlas_size.y, 0.001)
