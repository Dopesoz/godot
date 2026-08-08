class_name PreviewBuilder
extends RefCounted

## Сборка снимка мира. Отдельный класс, потому что главный скрипт `--script`
## компилируется до регистрации автозагрузок, и любое обращение к Events из
## него не проходит компиляцию. Этот файл загружается уже в рантайме.

## Размер снимка в клетках.
const VIEW_CELLS := Vector2i(46, 74)
const ZOOM: int = 2
const SEED: int = 20260807


func run(tree: SceneTree) -> void:
	Art.build()
	var world := GameWorld.new()
	tree.root.add_child(world)
	var simulation := Simulation.new()
	tree.root.add_child(simulation)
	world.simulation = simulation
	simulation.add_system(PowerSystem.new())
	simulation.add_system(BuildingSystem.new())
	simulation.add_system(ResearchSystem.new())
	simulation.add_system(LogisticsSystem.new())

	world.new_game(SEED)
	simulation.setup(world)
	GameSetup.create_starting_base(world)
	_build_demo_factory(world)

	# Даём фабрике поработать, чтобы на снимке были летящие дроны и продукция.
	simulation.game_time = 0.0
	for i: int in 900:
		simulation.tick()

	var origin: Vector2i = world.start_cell - VIEW_CELLS / 2
	var image: Image = _render(world, origin)
	image.resize(image.get_width() * ZOOM, image.get_height() * ZOOM, Image.INTERPOLATE_NEAREST)
	image.save_png("user://preview.png")
	print("Снимок: ", ProjectSettings.globalize_path("user://preview.png"))
	print("Зданий: %d, дронов в воздухе: %d" % [world.buildings.count(), _count_drones(world)])


## Небольшая показательная фабрика: бур на руде, печь, склад, панели.
func _build_demo_factory(world: GameWorld) -> void:
	var start: Vector2i = world.start_cell
	var ore_cell := Vector2i(-1, -1)
	for radius: int in range(5, 20):
		for dy: int in range(-radius, radius + 1):
			for dx: int in range(-radius, radius + 1):
				var cell: Vector2i = start + Vector2i(dx, dy)
				if world.grid.get_ore(cell) == TileTypes.Ore.IRON \
						and world.buildings.can_place(BuildingDefs.DRILL, cell):
					ore_cell = cell
					break
			if ore_cell.x >= 0:
				break
		if ore_cell.x >= 0:
			break

	if ore_cell.x >= 0:
		world.buildings.place(BuildingDefs.DRILL, ore_cell)
		world.buildings.place(BuildingDefs.SOLAR, ore_cell + Vector2i(0, 3))
	var furnace := world.buildings.place(BuildingDefs.FURNACE, start + Vector2i(4, 4)) as Furnace
	if furnace != null:
		furnace.set_recipe(Recipes.SMELT_IRON)
	world.buildings.place(BuildingDefs.FURNACE, start + Vector2i(4, 7))
	world.buildings.place(BuildingDefs.SOLAR, start + Vector2i(-4, 4))
	world.buildings.place(BuildingDefs.SOLAR, start + Vector2i(-4, 7))
	world.buildings.place(BuildingDefs.LAB, start + Vector2i(-1, 7))
	world.buildings.place(BuildingDefs.POLE, start + Vector2i(2, 3))


func _render(world: GameWorld, origin: Vector2i) -> Image:
	var tile: int = Constants.TILE_SIZE
	var image: Image = Image.create(VIEW_CELLS.x * tile, VIEW_CELLS.y * tile, false, Image.FORMAT_RGBA8)
	var terrain: Image = Art.terrain_texture.get_image()
	var objects: Image = Art.object_texture.get_image()

	# Поверхность и руда.
	for y: int in VIEW_CELLS.y:
		for x: int in VIEW_CELLS.x:
			var cell: Vector2i = origin + Vector2i(x, y)
			if not world.grid.in_bounds(cell):
				continue
			var destination := Vector2i(x * tile, y * tile)
			var variant: int = Art.variant_for(cell)
			_blit(image, terrain, Art.terrain_tile(world.grid.get_terrain(cell), variant) * tile, destination, tile)
			var ore: int = world.grid.get_ore(cell)
			if ore != TileTypes.Ore.NONE:
				_blit(image, terrain, Art.ore_tile(ore, variant) * tile, destination, tile)

	# Здания.
	for building: Building in world.buildings.in_rect(Rect2i(origin, VIEW_CELLS)):
		var region: Rect2i = Art.region(building.def_id)
		var position: Vector2i = (building.origin - origin) * tile
		_blit_rect(image, objects, region, position)

	# Курьеры: дроны в воздухе и носильщики пешком.
	for kind: int in BuildingDefs.COURIER_KINDS:
		var region: Rect2i = Art.region(
			ObjectArt.PORTER if kind == BuildingDefs.Kind.PORTER_HUT else ObjectArt.DRONE
		)
		for port_building: Building in world.buildings.of_kind(kind):
			for drone: Drone in (port_building as DronePort).drones:
				var position: Vector2i = Vector2i(drone.position) - origin * tile - region.size / 2
				_blit_rect(image, objects, region, position)
	return image


func _blit(target: Image, source: Image, from: Vector2i, to: Vector2i, size: int) -> void:
	_blit_rect(target, source, Rect2i(from, Vector2i(size, size)), to)


func _blit_rect(target: Image, source: Image, region: Rect2i, to: Vector2i) -> void:
	for y: int in region.size.y:
		for x: int in region.size.x:
			var destination: Vector2i = to + Vector2i(x, y)
			if destination.x < 0 or destination.y < 0 \
					or destination.x >= target.get_width() or destination.y >= target.get_height():
				continue
			var color: Color = source.get_pixel(region.position.x + x, region.position.y + y)
			if color.a <= 0.0:
				continue
			target.set_pixel(destination.x, destination.y, color)


func _count_drones(world: GameWorld) -> int:
	var count: int = 0
	for port: Building in LogisticsSystem.courier_bases(world.buildings):
		count += (port as DronePort).drone_count()
	return count
