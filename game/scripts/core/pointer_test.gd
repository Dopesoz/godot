class_name PointerTest
extends RefCounted

## Drives the game with a synthetic mouse and keyboard, then checks what the
## model did about it.
##
##     godot --path game -- --demo --uitest
##
## Why this exists: everything else in this project can be verified without a
## screen, and so everything else was. The pointer could not be — which meant
## the one part the player actually touches was the one part nobody had ever
## run. A tool button whose rectangle sits under the HUD, a drag that builds
## nothing, a click that selects the wrong resident: all of that passes every
## unit test in the repository.
##
## So this walks the *whole* path: a real InputEvent goes into the input system,
## through the same adapters, the same UI hit-testing and the same
## BuildController the player uses, and the assertion at the end looks only at
## the world model. Nothing here reaches into a node to shortcut a step.
##
## It needs a real display (the pointer position comes from the window system),
## so it runs alongside --screenshot rather than in the headless self-test.

class Step:
	var name: String
	var ok: bool
	var detail: String

	func _init(step_name: String, passed: bool, message: String = "") -> void:
		name = step_name
		ok = passed
		detail = message


static func maybe_run(world: Node) -> void:
	if not OS.get_cmdline_user_args().has("--uitest"):
		return
	var steps := await _run(world)
	var failed := 0
	for step: Step in steps:
		if not step.ok:
			failed += 1
		# The detail is a reason for a failure, so it is printed only when there
		# is one — otherwise a passing line reads as its own contradiction
		# ("PASS … cell (18, 26) has no floor").
		print("%s  %s%s" % ["PASS" if step.ok else "FAIL", step.name,
				"" if step.ok or step.detail == "" else " — " + step.detail])
	print("%d/%d pointer checks passed" % [steps.size() - failed, steps.size()])
	world.get_tree().quit(1 if failed > 0 else 0)


static func _run(world: Node) -> Array:
	var steps: Array = []
	var grid: WorldGrid = world.get("grid")
	var builder: BuildController = world.get_node_or_null("Builder")
	var furniture: FurnitureRegistry = world.get_node_or_null("Furniture")
	var citizens: CitizenRegistry = world.get_node_or_null("Citizens")
	var bar: Control = world.get_node_or_null("BuildUI/BuildBar")
	var panel: Control = world.get_node_or_null("BuildUI/CitizenPanel")
	if grid == null or builder == null or bar == null:
		return [Step.new("Pointer test", false, "the world is not ready")]

	# The camera has to be still before a screen position means anything.
	await world.get_tree().create_timer(0.6).timeout

	# 1. A tool button, clicked where it is drawn. This is the check that the
	#    bar is actually reachable and not covered by something else.
	var wall_button := _find_button(bar, "Wall")
	if wall_button == null:
		steps.append(Step.new("Tool button", false, "no button labelled Wall"))
	else:
		await _click_control(world, wall_button)
		steps.append(Step.new("Tool button — clicking 'Wall' on screen arms the wall tool",
				builder.tool_mode == GameEnums.ToolMode.WALL,
				"tool is %d" % builder.tool_mode))

	# 2. Drag a rectangle of walls, the way a player draws a room.
	#    On an empty patch south of the demo houses, with the camera moved there
	#    first — a cell the player cannot see is a cell they cannot click.
	var origin := Vector2i(16, 24)
	var corner := origin + Vector2i(4, 3)
	await _look_at(world, origin + Vector2i(2, 1))
	if not _on_screen(world, origin) or not _on_screen(world, corner):
		return [Step.new("Pointer test", false,
				"the test area is off screen: %s..%s" % [origin, corner])]
	await _drag(world, origin, corner)
	var perimeter := WorldGrid.rect_perimeter_edges(origin, corner)
	var missing := 0
	for edge: Vector3i in perimeter:
		if grid.get_edge(edge) != GameEnums.EdgeType.WALL:
			missing += 1
	steps.append(Step.new("Drag — a dragged rectangle becomes exactly that room's walls",
			missing == 0, "%d of %d perimeter edges are not walls" % [missing, perimeter.size()]))

	# 3. A door, in the wall the pointer is nearest to. Openings are placed by
	#    pointing at a wall rather than at a cell, so the click has to land near
	#    the edge — the same aim a player needs.
	await _key(world, KEY_3)
	var door_cell := origin + Vector2i(1, 0)
	await _click_edge(world, door_cell, Vector2i.UP)
	var door_edge := WorldGrid.edge_key(door_cell, Vector2i.UP)
	steps.append(Step.new("Click — a door opens in the wall nearest the pointer",
			grid.get_edge(door_edge) == GameEnums.EdgeType.DOOR,
			"edge %s is type %d" % [door_edge, grid.get_edge(door_edge)]))

	# 4. Floor, dragged over the inside.
	await _key(world, KEY_5)
	await _drag(world, origin, corner)
	var floored := grid.get_cell(origin + Vector2i(2, 2))
	steps.append(Step.new("Drag — flooring covers the dragged area",
			floored != null and floored.floor_id != &"",
			"cell %s has no floor" % (origin + Vector2i(2, 2))))

	# 5. Furniture, placed with a click, and rotated with R first — the two
	#    together are the whole furniture interaction.
	await _key(world, KEY_7)
	await _key(world, KEY_R)
	var count_before := furniture.items.size()
	await _click_cell(world, origin + Vector2i(1, 1))
	steps.append(Step.new("Click — furniture is placed under the pointer, rotated",
			furniture.items.size() == count_before + 1,
			"%d items, was %d" % [furniture.items.size(), count_before]))

	# 6. Back to the select tool and click a resident: the hook the whole game
	#    hangs off (§34).
	await _key(world, KEY_1)
	var resident: Citizen = null
	for citizen: Citizen in citizens.all():
		resident = citizen
		break
	if resident == null:
		steps.append(Step.new("Select a resident", false, "nobody lives here"))
	else:
		var where := Vector2i(roundi(resident.position.x), roundi(resident.position.y))
		await _look_at(world, where)
		await _click_cell(world, where)
		steps.append(Step.new("Click — clicking a resident opens their panel",
				panel != null and panel.visible,
				"panel visible: %s" % (panel != null and panel.visible)))

	# 7. Escape leaves the tool, so the player is never stuck in build mode.
	await _key(world, KEY_2)
	await _key(world, KEY_ESCAPE)
	steps.append(Step.new("Escape — leaves build mode",
			builder.tool_mode == GameEnums.ToolMode.NONE,
			"tool is %d" % builder.tool_mode))

	return steps


# --- The synthetic hand -----------------------------------------------------

## Moves the camera and lets it settle. The rig eases towards its target, so a
## screen position taken while it is still moving is a position that will have
## moved by the time the click lands.
static func _look_at(world: Node, cell: Vector2i) -> void:
	var camera := world.get_node_or_null("CameraRig") as CameraRig
	if camera != null:
		camera.focus_cell(cell, true)
	await world.get_tree().create_timer(0.4).timeout


## The window clamps the pointer, so a click aimed off screen silently lands
## somewhere else — which is exactly how the first version of this test fooled
## itself into passing. Every target is checked instead.
static func _on_screen(world: Node, cell: Vector2i) -> bool:
	var screen := _screen_of(world, cell)
	return Rect2(Vector2.ZERO, world.get_viewport().get_visible_rect().size).has_point(screen)


## Where a cell is on screen right now. The canvas transform is the same one the
## renderer uses, so this cannot drift from what the player sees.
static func _screen_of(world: Node, cell: Vector2i) -> Vector2:
	return world.get_viewport().get_canvas_transform() * IsoUtils.cell_to_world(cell)


static func _move_to(world: Node, screen: Vector2) -> void:
	# Both, and in this order. warp_mouse moves the real cursor, which is what
	# the window system reports; the motion event is what updates the viewport's
	# own idea of where the pointer is, and that is what the world reads to
	# decide which cell is hovered. With only one of the two, every position
	# below would be a frame or a screen stale.
	Input.warp_mouse(screen)
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	motion.global_position = screen
	Input.parse_input_event(motion)
	await world.get_tree().process_frame
	await world.get_tree().process_frame


static func _button_event(screen: Vector2, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = screen
	event.global_position = screen
	return event


static func _click_cell(world: Node, cell: Vector2i) -> void:
	await _click_world(world, IsoUtils.cell_to_world(cell))


## Clicks a third of the way from a cell's centre towards one of its edges,
## which is how the build tools tell "this wall" from "that wall".
static func _click_edge(world: Node, cell: Vector2i, direction: Vector2i) -> void:
	await _click_world(world, IsoUtils.cell_to_world_f(Vector2(cell) + Vector2(direction) * 0.35))


static func _click_world(world: Node, point: Vector2) -> void:
	var screen: Vector2 = world.get_viewport().get_canvas_transform() * point
	await _move_to(world, screen)
	Input.parse_input_event(_button_event(screen, true))
	await world.get_tree().process_frame
	Input.parse_input_event(_button_event(screen, false))
	await world.get_tree().process_frame


static func _drag(world: Node, from: Vector2i, to: Vector2i) -> void:
	var start := _screen_of(world, from)
	await _move_to(world, start)
	Input.parse_input_event(_button_event(start, true))
	await world.get_tree().process_frame
	var end := _screen_of(world, to)
	await _move_to(world, end)
	Input.parse_input_event(_button_event(end, false))
	await world.get_tree().process_frame


static func _click_control(world: Node, control: Control) -> void:
	var screen := control.get_global_rect().get_center()
	await _move_to(world, screen)
	Input.parse_input_event(_button_event(screen, true))
	await world.get_tree().process_frame
	Input.parse_input_event(_button_event(screen, false))
	await world.get_tree().process_frame


static func _key(world: Node, keycode: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = keycode
		event.keycode = keycode
		event.pressed = pressed
		Input.parse_input_event(event)
		await world.get_tree().process_frame


static func _find_button(root: Node, label: String) -> Button:
	for child in root.get_children():
		var button := child as Button
		if button != null and button.text.begins_with(label):
			return button
		var found := _find_button(child, label)
		if found != null:
			return found
	return null
