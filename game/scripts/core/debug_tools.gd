class_name DebugTools
extends RefCounted

## Small development-only helpers. Nothing here is part of the game.


## `godot --path game -- --demo` builds a small furnished flat with one
## resident, so the whole stack — walls, rooms, furniture, pathfinding, needs —
## can be seen (or smoke-tested in CI) without twenty clicks.
##
## Layout: a 7x6 flat split into a bedroom, a bathroom and a living/kitchen
## area, with doors between them and one door to the street.
static func maybe_build_demo(world: Node) -> void:
	if not OS.get_cmdline_user_args().has("--demo"):
		return
	build_demo(world)


static func build_demo(world: Node) -> void:
	var grid: WorldGrid = world.get("grid")
	var furniture: FurnitureRegistry = world.get_node_or_null("Furniture")
	var citizens: CitizenRegistry = world.get_node_or_null("Citizens")
	if grid == null or furniture == null or citizens == null:
		push_warning("DebugTools: the world is not ready for a demo build")
		return

	# Two neighbouring houses, each on its own plot with its own family. Two
	# households on one map is what the whole ownership rule exists for: the
	# Meyers do not sleep in the Novaks' bed.
	var lots: BuildingLots = world.get_node_or_null("Lots")
	var households: HouseholdRegistry = world.get_node_or_null("Households")

	_build_flat(grid, furniture, Vector2i(14, 15))
	_build_flat(grid, furniture, Vector2i(23, 15))

	if lots != null and households != null:
		var first := lots.place(&"house_small", Vector2i(14, 15))
		var second := lots.place(&"house_small", Vector2i(23, 15))
		# Placing a lot repaints cell ownership, so furniture has to be told
		# again which house it now stands in.
		for item: Furniture in furniture.items.values():
			item.building_id = grid.building_of(item.origin, item.floor_index)
		households.move_in(first, 2)
		households.move_in(second, 2)
	elif citizens != null:
		citizens.spawn(Vector2i(16, 18))
	EventBus.notify("Demo neighbourhood built")


## One furnished flat: bedroom top-left, bathroom top-right, kitchen and living
## room along the bottom. Doorways are kept clear of furniture — a stove in the
## doorway makes the room behind it unreachable.
static func _build_flat(grid: WorldGrid, furniture: FurnitureRegistry, origin: Vector2i) -> void:
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

	for cell in IsoUtils.cells_in_rect(origin, origin + Vector2i(6, 5)):
		grid.set_floor_material(cell, &"floor_wood")
	for cell in IsoUtils.cells_in_rect(origin + Vector2i(4, 0), origin + Vector2i(6, 1)):
		grid.set_floor_material(cell, &"floor_tile")
	for cell in IsoUtils.cells_in_rect(origin, origin + Vector2i(3, 2)):
		grid.set_floor_material(cell, &"floor_carpet")

	furniture.place(&"bed_single", origin + Vector2i(0, 0))
	furniture.place(&"bed_single", origin + Vector2i(1, 0))
	furniture.place(&"lamp", origin + Vector2i(2, 0))
	furniture.place(&"guitar", origin + Vector2i(3, 0))
	furniture.place(&"shower", origin + Vector2i(5, 0))
	furniture.place(&"desk", origin + Vector2i(5, 2))
	furniture.place(&"bookshelf", origin + Vector2i(4, 2))
	furniture.place(&"fridge", origin + Vector2i(0, 4))
	furniture.place(&"stove", origin + Vector2i(1, 4))
	furniture.place(&"coffee_machine", origin + Vector2i(2, 4))
	furniture.place(&"table_dining", origin + Vector2i(3, 4))
	furniture.place(&"sofa", origin + Vector2i(2, 5))
	furniture.place(&"tv", origin + Vector2i(6, 4))


## `godot --path game -- --screenshot out.png` renders the world for a moment,
## saves a PNG and quits. Used to eyeball the isometric projection from a
## terminal (and, later, to diff visual regressions in CI) without a human
## sitting in front of the window.
static func maybe_screenshot(node: Node) -> void:
	var args := OS.get_cmdline_user_args()
	var index := args.find("--screenshot")
	if index == -1:
		return
	var path := args[index + 1] if index + 1 < args.size() else "user://screenshot.png"
	# Let the scene settle: the camera eases into place over several frames.
	await node.get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	var image := node.get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	if error != OK:
		push_error("DebugTools: could not write %s (%d)" % [path, error])
	else:
		print("screenshot saved to ", path)
	node.get_tree().quit(0 if error == OK else 1)
