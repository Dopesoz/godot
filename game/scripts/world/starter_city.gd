class_name StarterCity
extends RefCounted

## The town the game starts in: houses with families in them, the places those
## families work, the places they go when they are not working, and the streets
## that join it all up.
##
## Why a town and not an empty field. This game's promise is looking *inside* a
## house (design doc §34), and an empty map asks the player to build one before
## it can keep that promise — twenty clicks before the first thing worth
## watching. Starting with a street means the first thing on screen is somebody
## making coffee, and the build tools become a way to change a place rather than
## a form to fill in.
##
## Everything here is built through the ordinary registries — the same calls the
## build tools make — so nothing in this file is a special case the player
## cannot undo, rebuild or delete. Roads are laid with the floor tool's own
## materials, walls with the wall tool's own edges.

## A crossroads through the middle of the map, with the buildings along it.
## Everything below is expressed relative to these two streets, so moving them
## moves the town.
const MAIN_STREET_Y := 30
const CROSS_STREET_X := 32
const ROAD_WIDTH := 2

## Buildings, in the order they are placed: template, where its walls start, and
## what to put inside.
const PLOTS := [
	{"lot": &"house_small", "at": Vector2i(10, 20), "kind": "house", "variant": 0, "family": 2},
	{"lot": &"house_small", "at": Vector2i(20, 20), "kind": "house", "variant": 1, "family": 3},
	{"lot": &"house_small", "at": Vector2i(40, 20), "kind": "house", "variant": 2, "family": 2},
	{"lot": &"house_small", "at": Vector2i(50, 20), "kind": "house", "variant": 0, "family": 2},
	{"lot": &"shop", "at": Vector2i(10, 35), "kind": "shop"},
	{"lot": &"cafe", "at": Vector2i(20, 35), "kind": "cafe"},
	{"lot": &"office", "at": Vector2i(40, 35), "kind": "office"},
	{"lot": &"gym", "at": Vector2i(51, 35), "kind": "gym"},
	{"lot": &"library", "at": Vector2i(40, 46), "kind": "library"},
	{"lot": &"park", "at": Vector2i(18, 46), "kind": "park"},
]

## Three furnishings of the same shell, so the first thing the player learns is
## that a house is a set of choices and not a fixed floor plan.
const VARIANTS := [
	{
		"floor": &"floor_wood", "bedroom_floor": &"floor_carpet", "bath_floor": &"floor_tile",
		"items": [
			[&"bed_single", Vector2i(0, 0)], [&"bed_single", Vector2i(1, 0)],
			[&"lamp", Vector2i(2, 0)], [&"guitar", Vector2i(3, 0)],
			[&"shower", Vector2i(5, 0)], [&"desk", Vector2i(4, 2)],
			[&"bookshelf", Vector2i(6, 2)],
			[&"fridge", Vector2i(0, 4)], [&"stove", Vector2i(1, 4)],
			[&"coffee_machine", Vector2i(2, 4)], [&"table_dining", Vector2i(3, 4)],
			[&"sofa", Vector2i(2, 5)], [&"dining_bench", Vector2i(4, 5)],
			[&"tv", Vector2i(6, 4)],
		],
	},
	{
		"floor": &"floor_wood", "bedroom_floor": &"floor_wood", "bath_floor": &"floor_tile",
		"items": [
			[&"bed_single", Vector2i(0, 0)], [&"bed_single", Vector2i(1, 0)],
			[&"bed_single", Vector2i(2, 0)], [&"bookshelf", Vector2i(3, 0)],
			[&"shower", Vector2i(5, 0)], [&"computer", Vector2i(4, 2)],
			[&"easel", Vector2i(6, 2)],
			[&"fridge", Vector2i(0, 4)], [&"kitchen_counter", Vector2i(1, 4)],
			[&"stove", Vector2i(3, 4)], [&"chair", Vector2i(4, 4)],
			[&"sofa", Vector2i(1, 5)], [&"tv", Vector2i(6, 4)],
			[&"lamp", Vector2i(6, 5)],
		],
	},
	{
		"floor": &"floor_carpet", "bedroom_floor": &"floor_carpet", "bath_floor": &"floor_tile",
		"items": [
			[&"bed_single", Vector2i(0, 0)], [&"bed_single", Vector2i(1, 0)],
			[&"treadmill", Vector2i(3, 0)], [&"shower", Vector2i(5, 0)],
			[&"desk", Vector2i(4, 2)], [&"lamp", Vector2i(6, 2)],
			[&"fridge", Vector2i(0, 4)], [&"stove", Vector2i(1, 4)],
			[&"kitchen_counter", Vector2i(2, 4)], [&"table_dining", Vector2i(4, 4)],
			[&"guitar", Vector2i(0, 5)], [&"dining_bench", Vector2i(4, 5)],
			[&"coffee_machine", Vector2i(6, 4)], [&"tv", Vector2i(6, 5)],
		],
	},
]


static func build(world: Node) -> void:
	var grid: WorldGrid = world.get("grid")
	var furniture := world.get_node_or_null("Furniture") as FurnitureRegistry
	var lots := world.get_node_or_null("Lots") as BuildingLots
	var households := world.get_node_or_null("Households") as HouseholdRegistry
	var buildings := world.get_node_or_null("Buildings") as BuildingRegistry
	if grid == null or furniture == null:
		push_warning("StarterCity: the world is not ready")
		return

	_streets(grid)
	for plot: Dictionary in PLOTS:
		_interior(grid, furniture, plot)

	if lots != null:
		for plot: Dictionary in PLOTS:
			lots.place(plot["lot"], (plot["at"] as Vector2i) - Vector2i.ONE)
		# Placing a plot repaints cell ownership, so every object has to be told
		# again which building it now stands in.
		for item: Furniture in furniture.items.values():
			item.building_id = grid.building_of(item.origin, item.floor_index)

	if buildings != null:
		buildings.rebuild()
		for plot: Dictionary in PLOTS:
			_name_rooms(buildings, plot)

	if lots != null and households != null:
		var index := 0
		var homes: Array = PLOTS.filter(func(plot: Dictionary) -> bool: return plot["kind"] == "house")
		for building: Building in lots.buildings.values():
			if not building.is_residential() or index >= homes.size():
				continue
			households.move_in(building, int(homes[index]["family"]))
			index += 1
	EventBus.notify("A town: four families, a shop, a cafe, an office, a gym, a library and a park")


# --- Streets ----------------------------------------------------------------

## One road across and one down, with pavement along both sides. Roads are
## floor materials, so this is exactly what the player would do with the floor
## tool — and cars find them by asking the ground what it is made of.
static func _streets(grid: WorldGrid) -> void:
	for x in range(2, grid.size.x - 2):
		for w in ROAD_WIDTH:
			grid.set_floor_material(Vector2i(x, MAIN_STREET_Y + w), &"road")
		grid.set_floor_material(Vector2i(x, MAIN_STREET_Y - 1), &"pavement")
		grid.set_floor_material(Vector2i(x, MAIN_STREET_Y + ROAD_WIDTH), &"pavement")
	for y in range(2, grid.size.y - 2):
		for w in ROAD_WIDTH:
			grid.set_floor_material(Vector2i(CROSS_STREET_X + w, y), &"road")
		if y < MAIN_STREET_Y - 1 or y > MAIN_STREET_Y + ROAD_WIDTH:
			grid.set_floor_material(Vector2i(CROSS_STREET_X - 1, y), &"pavement")
			grid.set_floor_material(Vector2i(CROSS_STREET_X + ROAD_WIDTH, y), &"pavement")


# --- Interiors --------------------------------------------------------------

static func _interior(grid: WorldGrid, furniture: FurnitureRegistry, plot: Dictionary) -> void:
	var at: Vector2i = plot["at"]
	match plot["kind"]:
		"house":
			_house(grid, furniture, at, VARIANTS[int(plot["variant"])])
		"shop":
			_shop(grid, furniture, at)
		"cafe":
			_cafe(grid, furniture, at)
		"office":
			_office(grid, furniture, at)
		"gym":
			_gym(grid, furniture, at)
		"library":
			_library(grid, furniture, at)
		"park":
			_park(grid, furniture, at)


## One house: a shell with a bedroom, a bathroom and a kitchen-living room.
## Doorways are kept clear of furniture — a stove in a doorway makes the room
## behind it unreachable, which the residents notice long before the player does.
static func _house(grid: WorldGrid, furniture: FurnitureRegistry, origin: Vector2i,
		variant: Dictionary) -> void:
	for edge in WorldGrid.rect_perimeter_edges(origin, origin + Vector2i(6, 5)):
		grid.set_edge(edge, GameEnums.EdgeType.WALL)
	for x in range(0, 4):
		grid.set_edge(WorldGrid.edge_key(origin + Vector2i(x, 2), Vector2i.DOWN), GameEnums.EdgeType.WALL)
	for y in range(0, 3):
		grid.set_edge(WorldGrid.edge_key(origin + Vector2i(3, y), Vector2i.RIGHT), GameEnums.EdgeType.WALL)
	for x in range(4, 7):
		grid.set_edge(WorldGrid.edge_key(origin + Vector2i(x, 1), Vector2i.DOWN), GameEnums.EdgeType.WALL)

	grid.set_edge(WorldGrid.edge_key(origin + Vector2i(1, 2), Vector2i.DOWN), GameEnums.EdgeType.DOOR)
	grid.set_edge(WorldGrid.edge_key(origin + Vector2i(5, 1), Vector2i.DOWN), GameEnums.EdgeType.DOOR)
	grid.set_edge(WorldGrid.edge_key(origin + Vector2i(5, 5), Vector2i.DOWN), GameEnums.EdgeType.DOOR)
	grid.set_edge(WorldGrid.edge_key(origin + Vector2i(1, 0), Vector2i.UP), GameEnums.EdgeType.WINDOW)
	grid.set_edge(WorldGrid.edge_key(origin + Vector2i(3, 5), Vector2i.DOWN), GameEnums.EdgeType.WINDOW)
	grid.set_edge(WorldGrid.edge_key(origin + Vector2i(6, 3), Vector2i.RIGHT), GameEnums.EdgeType.WINDOW)

	for cell in IsoUtils.cells_in_rect(origin, origin + Vector2i(6, 5)):
		grid.set_floor_material(cell, variant["floor"])
	for cell in IsoUtils.cells_in_rect(origin, origin + Vector2i(3, 2)):
		grid.set_floor_material(cell, variant["bedroom_floor"])
	for cell in IsoUtils.cells_in_rect(origin + Vector2i(4, 0), origin + Vector2i(6, 1)):
		grid.set_floor_material(cell, variant["bath_floor"])

	for entry: Array in variant["items"]:
		furniture.place(entry[0], origin + (entry[1] as Vector2i))
	# A garden path out to the pavement, so the house is part of the street.
	for step in range(1, 4):
		grid.set_floor_material(origin + Vector2i(5, 5 + step), &"pavement")


static func _shop(grid: WorldGrid, furniture: FurnitureRegistry, origin: Vector2i) -> void:
	_shell(grid, origin, Vector2i(6, 4), &"floor_tile", Vector2i(2, 4), Vector2i(4, 4))
	furniture.place(&"kitchen_counter", origin + Vector2i(1, 1))
	furniture.place(&"fridge", origin + Vector2i(0, 0))
	furniture.place(&"coffee_machine", origin + Vector2i(5, 0))
	furniture.place(&"dining_bench", origin + Vector2i(4, 3))
	furniture.place(&"bookshelf", origin + Vector2i(6, 1))


static func _cafe(grid: WorldGrid, furniture: FurnitureRegistry, origin: Vector2i) -> void:
	_shell(grid, origin, Vector2i(6, 4), &"floor_wood", Vector2i(3, 4), Vector2i(1, 4))
	furniture.place(&"coffee_machine", origin + Vector2i(0, 0))
	furniture.place(&"kitchen_counter", origin + Vector2i(1, 0))
	furniture.place(&"table_dining", origin + Vector2i(1, 2))
	furniture.place(&"dining_bench", origin + Vector2i(1, 3))
	furniture.place(&"table_dining", origin + Vector2i(4, 2))
	furniture.place(&"chair", origin + Vector2i(4, 3))
	furniture.place(&"guitar", origin + Vector2i(6, 0))


static func _office(grid: WorldGrid, furniture: FurnitureRegistry, origin: Vector2i) -> void:
	_shell(grid, origin, Vector2i(7, 5), &"floor_wood", Vector2i(3, 5), Vector2i(1, 5))
	furniture.place(&"desk", origin + Vector2i(0, 1))
	furniture.place(&"desk", origin + Vector2i(4, 1))
	furniture.place(&"computer", origin + Vector2i(2, 3))
	furniture.place(&"computer", origin + Vector2i(6, 3))
	furniture.place(&"coffee_machine", origin + Vector2i(0, 4))
	furniture.place(&"bookshelf", origin + Vector2i(7, 0))
	furniture.place(&"chair", origin + Vector2i(4, 4))


static func _gym(grid: WorldGrid, furniture: FurnitureRegistry, origin: Vector2i) -> void:
	_shell(grid, origin, Vector2i(7, 5), &"floor_tile", Vector2i(3, 5), Vector2i(5, 5))
	furniture.place(&"treadmill", origin + Vector2i(0, 0))
	furniture.place(&"treadmill", origin + Vector2i(2, 0))
	furniture.place(&"treadmill", origin + Vector2i(4, 0))
	furniture.place(&"shower", origin + Vector2i(7, 0))
	furniture.place(&"shower", origin + Vector2i(7, 2))
	furniture.place(&"dining_bench", origin + Vector2i(1, 4))
	furniture.place(&"coffee_machine", origin + Vector2i(6, 5))


static func _library(grid: WorldGrid, furniture: FurnitureRegistry, origin: Vector2i) -> void:
	_shell(grid, origin, Vector2i(7, 5), &"floor_wood", Vector2i(3, 5), Vector2i(6, 5))
	for x in [0, 2, 4, 6]:
		furniture.place(&"bookshelf", origin + Vector2i(x, 0))
	furniture.place(&"desk", origin + Vector2i(1, 3))
	furniture.place(&"desk", origin + Vector2i(4, 3))
	furniture.place(&"computer", origin + Vector2i(7, 2))
	furniture.place(&"lamp", origin + Vector2i(0, 5))


## A park has no walls, which is the point: it is the one place in town that is
## just outside, and the pathfinder treats it like any other open ground.
static func _park(grid: WorldGrid, furniture: FurnitureRegistry, origin: Vector2i) -> void:
	for cell in IsoUtils.cells_in_rect(origin, origin + Vector2i(8, 6)):
		if cell.x == origin.x + 4 or cell.y == origin.y + 3:
			grid.set_floor_material(cell, &"pavement")
	for spot in [Vector2i(0, 0), Vector2i(8, 0), Vector2i(0, 6), Vector2i(8, 6),
			Vector2i(2, 5), Vector2i(6, 1)]:
		furniture.place(&"tree", origin + spot)
	furniture.place(&"dining_bench", origin + Vector2i(2, 2))
	furniture.place(&"dining_bench", origin + Vector2i(5, 4))
	furniture.place(&"lamp", origin + Vector2i(4, 3))
	furniture.place(&"guitar", origin + Vector2i(6, 5))


## Four walls, a floor, a door and a window — the part every building shares.
static func _shell(grid: WorldGrid, origin: Vector2i, extent: Vector2i, material: StringName,
		door: Vector2i, window: Vector2i) -> void:
	for edge in WorldGrid.rect_perimeter_edges(origin, origin + extent):
		grid.set_edge(edge, GameEnums.EdgeType.WALL)
	for cell in IsoUtils.cells_in_rect(origin, origin + extent):
		grid.set_floor_material(cell, material)
	grid.set_edge(WorldGrid.edge_key(origin + door, Vector2i.DOWN), GameEnums.EdgeType.DOOR)
	grid.set_edge(WorldGrid.edge_key(origin + window, Vector2i.DOWN), GameEnums.EdgeType.WINDOW)
	grid.set_edge(WorldGrid.edge_key(origin + Vector2i(1, 0), Vector2i.UP), GameEnums.EdgeType.WINDOW)
	# A path from the door to wherever the pavement is.
	for step in range(1, 4):
		grid.set_floor_material(origin + door + Vector2i(0, step), &"pavement")


## Rooms are detected on their own; what they are *for* is a decision, so the
## town makes it the way a player would with the room tool.
static func _name_rooms(buildings: BuildingRegistry, plot: Dictionary) -> void:
	var at: Vector2i = plot["at"]
	var entries: Array = []
	match plot["kind"]:
		"house":
			entries = [
				[Vector2i(1, 1), GameEnums.RoomType.BEDROOM],
				[Vector2i(5, 0), GameEnums.RoomType.BATHROOM],
				[Vector2i(2, 4), GameEnums.RoomType.LIVING_ROOM],
			]
		"shop", "cafe":
			entries = [[Vector2i(2, 2), GameEnums.RoomType.SHOP]]
		"office", "library":
			entries = [[Vector2i(2, 2), GameEnums.RoomType.OFFICE]]
		"gym":
			entries = [[Vector2i(2, 2), GameEnums.RoomType.LIVING_ROOM]]
	for entry: Array in entries:
		var room := buildings.room_at(at + (entry[0] as Vector2i))
		if room != null:
			buildings.set_room_type(room.id, entry[1] as GameEnums.RoomType)
