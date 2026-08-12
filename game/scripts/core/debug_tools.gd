class_name DebugTools
extends RefCounted

## Small development-only helpers. Nothing here is part of the game.


## `--demo` used to build a flat of its own. It no longer needs to: a new game
## already starts in the starter town, so the flag survives only as a promise
## that the town is there — scripts and CI jobs that pass it keep working.
static func maybe_build_demo(world: Node) -> void:
	if not OS.get_cmdline_user_args().has("--demo"):
		return
	# The starter town *is* the demo now — one town, built one way, so what the
	# tests measure is what the player gets.
	if world.get_node_or_null("Lots") != null \
			and (world.get_node_or_null("Lots") as BuildingLots).buildings.is_empty():
		StarterCity.build(world)


## `godot --path game -- --showroom` lays one of every furniture template out on
## a grid, each on its own patch of floor, in both orientations.
##
## It exists because art is the one part of this project that cannot be checked
## by an assertion: a sprite can be the right size, load correctly, sit on the
## right cells and still look wrong. This puts the whole catalogue on screen at
## once so a person (or a screenshot in review) can see all of it in one look.
static func maybe_build_showroom(world: Node) -> void:
	if not OS.get_cmdline_user_args().has("--showroom"):
		return
	var grid: WorldGrid = world.get("grid")
	var furniture: FurnitureRegistry = world.get_node_or_null("Furniture")
	if grid == null or furniture == null:
		return

	const COLUMNS := 6
	const PITCH := 4
	var templates := Database.all_furniture()
	var origin := Vector2i(6, 6)
	var slot := 0
	for template: FurnitureData in templates:
		for rotation in [0, 1]:
			var at := origin + Vector2i(slot % COLUMNS, slot / COLUMNS) * PITCH
			for cell in IsoUtils.cells_in_rect(at - Vector2i.ONE,
					at + template.rotated_size(rotation)):
				grid.set_floor_material(cell, &"floor_tile" if rotation == 0 else &"floor_wood")
			furniture.place(template.id, at, rotation)
			slot += 1
	EventBus.notify("Showroom: %d templates" % templates.size())


## `godot --path game -- --bench 200` fills the demo neighbourhood with N
## residents and measures what the simulation actually costs, in milliseconds
## per frame, split by detail level. Performance claims should be measured, not
## assumed — especially for a phone.
static func maybe_benchmark(world: Node) -> void:
	var args := OS.get_cmdline_user_args()
	var index := args.find("--bench")
	if index == -1:
		return
	var wanted := int(args[index + 1]) if index + 1 < args.size() else 100
	await world.get_tree().process_frame

	var grid: WorldGrid = world.get("grid")
	var citizens: CitizenRegistry = world.get_node_or_null("Citizens")
	if grid == null or citizens == null:
		return
	# Spread them across the map so every level of detail is exercised, which is
	# the realistic case — a real city is not all on screen at once.
	var spawned := 0
	for y in range(1, grid.size.y - 1):
		for x in range(1, grid.size.x - 1):
			if spawned >= wanted:
				break
			if citizens.spawn(Vector2i(x, y)) != null:
				spawned += 1
	GameClock.set_speed_index(GameConstants.TIME_SPEEDS.size() - 1)
	print("[bench] %d residents spawned, measuring…" % spawned)

	# Warm up first: the first frames include spawning and path caches.
	for i in 30:
		await world.get_tree().process_frame
	var frames := 240
	var started := Time.get_ticks_usec()
	for i in frames:
		await world.get_tree().process_frame
	var elapsed_ms := float(Time.get_ticks_usec() - started) / 1000.0

	print("[bench] %d residents | %.2f ms/frame total loop | %d full / %d reduced / %d abstract | %d fps equivalent" % [
		spawned,
		elapsed_ms / float(frames),
		SimScheduler.counts[GameEnums.SimLOD.FULL],
		SimScheduler.counts[GameEnums.SimLOD.REDUCED],
		SimScheduler.counts[GameEnums.SimLOD.ABSTRACT],
		roundi(1000.0 / maxf(elapsed_ms / float(frames), 0.001)),
	])
	world.get_tree().quit()


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
	# `--focus x,y` and `--zoom n` are what make this useful for looking at art:
	# the interesting question is usually "how does one room read close up", not
	# "how does the whole map look".
	# `--hour 22` jumps the clock, because half the art only exists after dark:
	# lit windows, lamplight in the rooms, the blue outside.
	var hour := args.find("--hour")
	if hour != -1 and hour + 1 < args.size():
		GameClock.advance((float(args[hour + 1]) - GameClock.hour_of_day()) * 60.0)
	var camera := node.get_node_or_null("CameraRig") as CameraRig
	if camera != null:
		var focus := args.find("--focus")
		if focus != -1 and focus + 1 < args.size():
			var parts := args[focus + 1].split(",")
			if parts.size() == 2:
				camera.focus_cell(Vector2i(int(parts[0]), int(parts[1])), true)
		var zoom := args.find("--zoom")
		if zoom != -1 and zoom + 1 < args.size():
			camera.set_zoom_level(float(args[zoom + 1]))
	# `--select` opens the resident panel, which is otherwise only reachable by
	# clicking — and its layout is one of the things worth looking at.
	if args.has("--select"):
		var registry := node.get_node_or_null("Citizens") as CitizenRegistry
		for citizen: Citizen in (registry.all() if registry != null else []):
			EventBus.selection_changed.emit(citizen)
			break
	# `--walls 1` taps E once before the shot. Injected as a real key event
	# rather than by reaching into the renderer, so what the screenshot shows is
	# what the player's keyboard would do.
	var walls := args.find("--walls")
	if walls != -1 and walls + 1 < args.size():
		for i in int(args[walls + 1]):
			for pressed in [true, false]:
				var key := InputEventKey.new()
				key.physical_keycode = KEY_E
				key.pressed = pressed
				Input.parse_input_event(key)
			await node.get_tree().process_frame
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
