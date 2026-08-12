class_name StarterCity
extends RefCounted

## The town the game starts in: three furnished houses with families living in
## them, a shop and an office where those families work.
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
## cannot undo, rebuild or delete. Walls, floors and furniture can all be edited
## afterwards, because they were placed the same way the player would place them.

## Two houses on the left, one on the right, and the two workplaces below, with
## room between them for whatever the player wants to add.
const HOUSES := [
	{"at": Vector2i(6, 8), "family": 2, "variant": 0},
	{"at": Vector2i(16, 8), "family": 3, "variant": 1},
	{"at": Vector2i(26, 8), "family": 2, "variant": 2},
]

## Three furnishings of the same shell, so the first thing the player learns is
## that a house is a set of choices and not a fixed floor plan.
const VARIANTS := [
	{
		"floor": &"floor_wood", "bedroom_floor": &"floor_carpet", "bath_floor": &"floor_tile",
		"items": [
			[&"bed_single", Vector2i(0, 0), 0], [&"bed_single", Vector2i(1, 0), 0],
			[&"lamp", Vector2i(2, 0), 0], [&"guitar", Vector2i(3, 0), 0],
			[&"shower", Vector2i(5, 0), 0], [&"desk", Vector2i(4, 2), 0],
			[&"bookshelf", Vector2i(6, 2), 0],
			[&"fridge", Vector2i(0, 4), 0], [&"stove", Vector2i(1, 4), 0],
			[&"coffee_machine", Vector2i(2, 4), 0], [&"table_dining", Vector2i(3, 4), 0],
			[&"sofa", Vector2i(2, 5), 0], [&"dining_bench", Vector2i(4, 5), 0],
			[&"tv", Vector2i(6, 4), 0],
		],
	},
	{
		"floor": &"floor_wood", "bedroom_floor": &"floor_wood", "bath_floor": &"floor_tile",
		"items": [
			[&"bed_single", Vector2i(0, 0), 0], [&"bed_single", Vector2i(1, 0), 0],
			[&"bed_single", Vector2i(2, 0), 0], [&"bookshelf", Vector2i(3, 0), 0],
			[&"shower", Vector2i(5, 0), 0], [&"computer", Vector2i(4, 2), 0],
			[&"easel", Vector2i(6, 2), 0],
			[&"fridge", Vector2i(0, 4), 0], [&"kitchen_counter", Vector2i(1, 4), 0],
			[&"stove", Vector2i(3, 4), 0], [&"chair", Vector2i(4, 4), 0],
			[&"sofa", Vector2i(1, 5), 0], [&"tv", Vector2i(6, 4), 0],
			[&"lamp", Vector2i(6, 5), 0],
		],
	},
	{
		"floor": &"floor_carpet", "bedroom_floor": &"floor_carpet", "bath_floor": &"floor_tile",
		"items": [
			[&"bed_single", Vector2i(0, 0), 0], [&"bed_single", Vector2i(1, 0), 0],
			[&"treadmill", Vector2i(3, 0), 0], [&"shower", Vector2i(5, 0), 0],
			[&"desk", Vector2i(4, 2), 0], [&"lamp", Vector2i(6, 2), 0],
			[&"fridge", Vector2i(0, 4), 0], [&"stove", Vector2i(1, 4), 0],
			[&"kitchen_counter", Vector2i(2, 4), 0], [&"table_dining", Vector2i(4, 4), 0],
			[&"guitar", Vector2i(0, 5), 0], [&"dining_bench", Vector2i(4, 5), 0],
			[&"coffee_machine", Vector2i(6, 4), 0], [&"tv", Vector2i(6, 5), 0],
		],
	},
]

const SHOP_AT := Vector2i(9, 24)
const OFFICE_AT := Vector2i(23, 24)


static func build(world: Node) -> void:
	var grid: WorldGrid = world.get("grid")
	var furniture := world.get_node_or_null("Furniture") as FurnitureRegistry
	var lots := world.get_node_or_null("Lots") as BuildingLots
	var households := world.get_node_or_null("Households") as HouseholdRegistry
	var buildings := world.get_node_or_null("Buildings") as BuildingRegistry
	if grid == null or furniture == null:
		push_warning("StarterCity: the world is not ready")
		return

	for house: Dictionary in HOUSES:
		_house(grid, furniture, house["at"], VARIANTS[int(house["variant"])])
	_shop(grid, furniture, SHOP_AT)
	_office(grid, furniture, OFFICE_AT)

	if lots != null:
		for house: Dictionary in HOUSES:
			lots.place(&"house_small", (house["at"] as Vector2i) - Vector2i.ONE)
		lots.place(&"shop", SHOP_AT - Vector2i.ONE)
		lots.place(&"office", OFFICE_AT - Vector2i.ONE)
		# Placing a plot repaints cell ownership, so every object has to be told
		# again which building it now stands in.
		for item: Furniture in furniture.items.values():
			item.building_id = grid.building_of(item.origin, item.floor_index)

	if buildings != null:
		buildings.rebuild()
		for house: Dictionary in HOUSES:
			_name_rooms(buildings, house["at"], [
				[Vector2i(1, 1), GameEnums.RoomType.BEDROOM],
				[Vector2i(5, 0), GameEnums.RoomType.BATHROOM],
				[Vector2i(2, 4), GameEnums.RoomType.LIVING_ROOM],
			])
		_name_rooms(buildings, SHOP_AT, [[Vector2i(2, 2), GameEnums.RoomType.SHOP]])
		_name_rooms(buildings, OFFICE_AT, [[Vector2i(2, 2), GameEnums.RoomType.OFFICE]])

	if lots != null and households != null:
		var index := 0
		for building: Building in lots.buildings.values():
			if building.data_id != &"house_small" or index >= HOUSES.size():
				continue
			households.move_in(building, int(HOUSES[index]["family"]))
			index += 1
	EventBus.notify("A small town, three families, a shop and an office")


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
		furniture.place(entry[0], origin + (entry[1] as Vector2i), int(entry[2]))


## A shop: one open room with a counter to work behind and somewhere to sit.
static func _shop(grid: WorldGrid, furniture: FurnitureRegistry, origin: Vector2i) -> void:
	_shell(grid, origin, Vector2i(6, 4), &"floor_tile")
	grid.set_edge(WorldGrid.edge_key(origin + Vector2i(2, 4), Vector2i.DOWN), GameEnums.EdgeType.DOOR)
	grid.set_edge(WorldGrid.edge_key(origin + Vector2i(4, 4), Vector2i.DOWN), GameEnums.EdgeType.WINDOW)
	grid.set_edge(WorldGrid.edge_key(origin + Vector2i(1, 0), Vector2i.UP), GameEnums.EdgeType.WINDOW)
	furniture.place(&"kitchen_counter", origin + Vector2i(1, 1))
	furniture.place(&"fridge", origin + Vector2i(0, 0))
	furniture.place(&"coffee_machine", origin + Vector2i(5, 0))
	furniture.place(&"dining_bench", origin + Vector2i(4, 3))
	furniture.place(&"bookshelf", origin + Vector2i(6, 1))


## An office: desks, computers and the coffee machine that makes them bearable.
static func _office(grid: WorldGrid, furniture: FurnitureRegistry, origin: Vector2i) -> void:
	_shell(grid, origin, Vector2i(7, 5), &"floor_wood")
	grid.set_edge(WorldGrid.edge_key(origin + Vector2i(3, 5), Vector2i.DOWN), GameEnums.EdgeType.DOOR)
	grid.set_edge(WorldGrid.edge_key(origin + Vector2i(1, 5), Vector2i.DOWN), GameEnums.EdgeType.WINDOW)
	grid.set_edge(WorldGrid.edge_key(origin + Vector2i(5, 0), Vector2i.UP), GameEnums.EdgeType.WINDOW)
	furniture.place(&"desk", origin + Vector2i(0, 1))
	furniture.place(&"desk", origin + Vector2i(4, 1))
	furniture.place(&"computer", origin + Vector2i(2, 3))
	furniture.place(&"computer", origin + Vector2i(6, 3))
	furniture.place(&"coffee_machine", origin + Vector2i(0, 4))
	furniture.place(&"bookshelf", origin + Vector2i(7, 0))
	furniture.place(&"chair", origin + Vector2i(4, 4))


## Four walls and a floor — the part every building has in common.
static func _shell(grid: WorldGrid, origin: Vector2i, extent: Vector2i, material: StringName) -> void:
	for edge in WorldGrid.rect_perimeter_edges(origin, origin + extent):
		grid.set_edge(edge, GameEnums.EdgeType.WALL)
	for cell in IsoUtils.cells_in_rect(origin, origin + extent):
		grid.set_floor_material(cell, material)


## Rooms are detected on their own; what they are *for* is a decision, so the
## town makes it the way a player would with the room tool.
static func _name_rooms(buildings: BuildingRegistry, origin: Vector2i, entries: Array) -> void:
	for entry: Array in entries:
		var room := buildings.room_at(origin + (entry[0] as Vector2i))
		if room != null:
			buildings.set_room_type(room.id, entry[1] as GameEnums.RoomType)
