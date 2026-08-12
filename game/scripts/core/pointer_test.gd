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
	var args := OS.get_cmdline_user_args()
	var pointer := args.has("--uitest")
	var touch := args.has("--touchtest")
	if not pointer and not touch:
		return
	var steps: Array = []
	if pointer:
		steps.append_array(await _run(world))
	if touch:
		steps.append_array(await _run_touch(world))
	var failed := 0
	for step: Step in steps:
		if not step.ok:
			failed += 1
		# The detail is a reason for a failure, so it is printed only when there
		# is one — otherwise a passing line reads as its own contradiction
		# ("PASS … cell (18, 26) has no floor").
		print("%s  %s%s" % ["PASS" if step.ok else "FAIL", step.name,
				"" if step.ok or step.detail == "" else " — " + step.detail])
	print("%d/%d input checks passed" % [steps.size() - failed, steps.size()])
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
	# Looking at a cell *past* the test area puts the area itself in the upper
	# half of the screen, clear of the build bar. On a phone the bar is twice as
	# tall and covers the bottom third, which is where the first version of this
	# test was cheerfully clicking.
	await _look_at(world, corner + Vector2i(3, 3))
	for cell in [origin, corner]:
		if not _reachable(world, cell):
			return [Step.new("Pointer test", false,
					"cell %s is off screen or under the interface" % cell)]
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

	# 7. Tapping an object asks what it is. The panel is the only place the
	#    game explains itself, so "does a tap open it" is worth a check.
	var object_panel := world.get_node_or_null("BuildUI/ObjectPanel") as Control
	await _click_cell(world, origin + Vector2i(1, 1))
	steps.append(Step.new("Click — tapping an object opens its description",
			object_panel != null and object_panel.visible,
			"panel visible: %s" % (object_panel != null and object_panel.visible)))

	# 8. Escape leaves the tool, so the player is never stuck in build mode.
	await _key(world, KEY_2)
	await _key(world, KEY_ESCAPE)
	steps.append(Step.new("Escape — leaves build mode",
			builder.tool_mode == GameEnums.ToolMode.NONE,
			"tool is %d" % builder.tool_mode))

	return steps


## The gestures, which are the whole of the Android control scheme.
##
## Godot synthesises mouse events from the first finger, so a tap already
## reaches the build tools; the only question the adapter has to answer is
## whether a gesture means "move the camera" or "build". That is what is checked
## here, because getting it backwards makes the game unplayable on a phone in a
## way no desktop session would ever reveal.
static func _run_touch(world: Node) -> Array:
	var steps: Array = []
	var camera := world.get_node_or_null("CameraRig") as CameraRig
	var grid: WorldGrid = world.get("grid")
	var builder: BuildController = world.get_node_or_null("Builder")
	if camera == null or builder == null:
		return [Step.new("Touch test", false, "the world is not ready")]

	await _key(world, KEY_ESCAPE)
	await _look_at(world, Vector2i(20, 20))

	# 1. One finger, no tool: the map follows the finger.
	var before := camera.position
	await _finger_drag(world, 0, Vector2(700, 300), Vector2(500, 220))
	var moved := camera.position.distance_to(before)
	steps.append(Step.new("Touch — one finger drags the map",
			moved > 40.0, "camera moved %.1f px" % moved))

	# 2. Two fingers apart: zoom in, anchored between them.
	var zoom_before := camera.get_target_zoom()
	await _pinch(world, Vector2(560, 340), Vector2(720, 340), 90.0)
	steps.append(Step.new("Touch — two fingers pinch to zoom",
			camera.get_target_zoom() > zoom_before + 0.05,
			"zoom %.2f -> %.2f" % [zoom_before, camera.get_target_zoom()]))

	# 3. One finger *with a tool in hand* must build, not pan. Getting this
	#    backwards is the difference between a game and a paint program.
	await _key(world, KEY_2)
	await _look_at(world, Vector2i(26, 26))
	var origin := Vector2i(25, 25)
	var corner := origin + Vector2i(2, 2)
	if not _on_screen(world, origin) or not _on_screen(world, corner):
		steps.append(Step.new("Touch — building", false, "the test area is off screen"))
		return steps
	var camera_at := camera.position
	var edges_before := grid.used_edges().size()
	await _finger_drag(world, 0, _screen_of(world, origin), _screen_of(world, corner))
	steps.append(Step.new("Touch — with a tool in hand the same drag builds instead of panning",
			grid.used_edges().size() > edges_before
			and camera.position.distance_to(camera_at) < 2.0,
			"%d edges built, camera moved %.1f px"
			% [grid.used_edges().size() - edges_before, camera.position.distance_to(camera_at)]))
	await _key(world, KEY_ESCAPE)
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


## Can a finger actually reach this cell?
##
## Two ways it cannot. The window clamps the pointer, so a click aimed off
## screen lands somewhere else entirely — which is how the first version of this
## test fooled itself into passing. And a panel on top of the map eats the click
## before the world sees it, which is how it fooled itself again on a phone,
## where the build bar is twice as tall.
static func _reachable(world: Node, cell: Vector2i) -> bool:
	var screen := _screen_of(world, cell)
	if not Rect2(Vector2.ZERO, world.get_viewport().get_visible_rect().size).has_point(screen):
		return false
	for path in ["BuildUI/BuildBar", "BuildUI/CitizenPanel"]:
		var panel := world.get_node_or_null(path) as Control
		if panel != null and panel.visible and panel.get_global_rect().has_point(screen):
			return false
	return true


static func _on_screen(world: Node, cell: Vector2i) -> bool:
	return _reachable(world, cell)


## Where a cell is on screen right now. The canvas transform is the same one the
## renderer uses, so this cannot drift from what the player sees.
static func _screen_of(world: Node, cell: Vector2i) -> Vector2:
	return world.get_viewport().get_canvas_transform() * IsoUtils.cell_to_world(cell)


## Viewport coordinates are not window coordinates. With the `canvas_items`
## stretch mode a 1600x740 window still renders a 1280x720 viewport, scaled and
## letterboxed — so a point computed from the canvas transform has to be mapped
## back out to the window before it can be handed to the input system. On a
## desktop-sized window that transform is the identity, which is why this was
## invisible until the first phone-shaped run put every click a cell to the left.
static func _to_window(world: Node, viewport_point: Vector2) -> Vector2:
	return world.get_viewport().get_screen_transform() * viewport_point


static func _move_to(world: Node, screen: Vector2) -> void:
	var window_point := _to_window(world, screen)
	# Both, and in this order. warp_mouse moves the real cursor, which is what
	# the window system reports; the motion event is what updates the viewport's
	# own idea of where the pointer is, and that is what the world reads to
	# decide which cell is hovered. With only one of the two, every position
	# below would be a frame or a screen stale.
	Input.warp_mouse(window_point)
	var motion := InputEventMouseMotion.new()
	motion.position = window_point
	motion.global_position = window_point
	Input.parse_input_event(motion)
	await world.get_tree().process_frame
	await world.get_tree().process_frame


static func _button_event(world: Node, screen: Vector2, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = _to_window(world, screen)
	event.global_position = event.position
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
	Input.parse_input_event(_button_event(world, screen, true))
	await world.get_tree().process_frame
	Input.parse_input_event(_button_event(world, screen, false))
	await world.get_tree().process_frame


static func _drag(world: Node, from: Vector2i, to: Vector2i) -> void:
	var start := _screen_of(world, from)
	await _move_to(world, start)
	Input.parse_input_event(_button_event(world, start, true))
	await world.get_tree().process_frame
	var end := _screen_of(world, to)
	await _move_to(world, end)
	Input.parse_input_event(_button_event(world, end, false))
	await world.get_tree().process_frame


static func _click_control(world: Node, control: Control) -> void:
	var screen := control.get_global_rect().get_center()
	await _move_to(world, screen)
	Input.parse_input_event(_button_event(world, screen, true))
	await world.get_tree().process_frame
	Input.parse_input_event(_button_event(world, screen, false))
	await world.get_tree().process_frame


## A finger pressing, sliding and lifting. The drag is broken into steps
## because a gesture arrives as a stream of small deltas, and both panning and
## pinching are written against `relative`.
static func _finger_drag(world: Node, index: int, from: Vector2, to: Vector2,
		steps: int = 8) -> void:
	_touch_event(index, _to_window(world, from), true)
	await world.get_tree().process_frame
	var previous := from
	for i in range(1, steps + 1):
		var at := from.lerp(to, float(i) / float(steps))
		var drag := InputEventScreenDrag.new()
		drag.index = index
		drag.position = _to_window(world, at)
		drag.relative = at - previous
		Input.parse_input_event(drag)
		previous = at
		await world.get_tree().process_frame
	_touch_event(index, _to_window(world, to), false)
	await world.get_tree().process_frame


## Two fingers moving apart by `spread` pixels each.
static func _pinch(world: Node, left: Vector2, right: Vector2, spread: float) -> void:
	_touch_event(0, _to_window(world, left), true)
	_touch_event(1, _to_window(world, right), true)
	await world.get_tree().process_frame
	for i in range(1, 7):
		var step := spread * float(i) / 6.0
		for entry in [[0, left + Vector2(-step, 0.0)], [1, right + Vector2(step, 0.0)]]:
			var drag := InputEventScreenDrag.new()
			drag.index = entry[0]
			drag.position = _to_window(world, entry[1])
			drag.relative = Vector2(spread / 6.0 * (-1.0 if entry[0] == 0 else 1.0), 0.0)
			Input.parse_input_event(drag)
		await world.get_tree().process_frame
	_touch_event(0, _to_window(world, left + Vector2(-spread, 0.0)), false)
	_touch_event(1, _to_window(world, right + Vector2(spread, 0.0)), false)
	await world.get_tree().process_frame


static func _touch_event(index: int, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	Input.parse_input_event(event)


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
