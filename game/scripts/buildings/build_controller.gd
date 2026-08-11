class_name BuildController
extends Node

## The build mode (design doc §8). Owns the active tool, the drag in progress
## and the rules about what may be built where — but not the drawing: the
## preview layer reads the plan below and renders it.
##
## Every tool follows the same three steps, which is what keeps this file small
## and makes adding a tool later cheap:
##
##   1. `_plan_*`  works out what would change, and what it would cost.
##   2. the preview layer draws that plan while the pointer moves.
##   3. `_apply`   charges the player once and writes it into the WorldGrid.
##
## Nothing here knows about pixels beyond asking WorldController which cell and
## which edge the pointer is on, so a touch adapter can drive the same flow.

## How close to a cell border the pointer must be, in cell fractions, to be
## considered "pointing at that edge" rather than at the cell.
const EDGE_PICK_THRESHOLD := 0.35

var tool_mode: int = GameEnums.ToolMode.NONE
var selected_floor_id: StringName = &"floor_wood"
var selected_room_type: int = GameEnums.RoomType.LIVING_ROOM

## The plan the preview layer draws. Rebuilt whenever the pointer moves.
var preview_cells: Array[Vector2i] = []
var preview_edges: Array[Vector3i] = []
var preview_cost: int = 0
var preview_valid: bool = false

var _dragging: bool = false
var _drag_start: Vector2i = Vector2i.ZERO

@onready var _world: WorldController = get_parent() as WorldController


func _ready() -> void:
	if _world == null:
		push_error("BuildController must be a child of WorldController")
		set_process(false)


func set_tool(mode: int) -> void:
	if mode == tool_mode:
		return
	tool_mode = mode
	_dragging = false
	_clear_preview()
	EventBus.tool_mode_changed.emit(tool_mode)


func is_building() -> bool:
	return tool_mode != GameEnums.ToolMode.NONE


func _process(_delta: float) -> void:
	if not is_building():
		return
	_rebuild_preview()


# --- Input ------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if Input.is_action_just_pressed(InputActions.BUILD_CANCEL):
		if _dragging:
			_dragging = false
			_clear_preview()
		else:
			set_tool(GameEnums.ToolMode.NONE)
		return
	if not is_building() or not (event is InputEventMouseButton):
		return
	var button := event as InputEventMouseButton
	if button.button_index != MOUSE_BUTTON_LEFT:
		return
	get_viewport().set_input_as_handled()

	if button.pressed:
		if _is_drag_tool():
			_dragging = true
			_drag_start = _world.hovered_cell
		else:
			_apply_click()
	elif _dragging:
		_dragging = false
		_apply_drag()


## Wall, floor and delete work over a rectangle; doors, windows and room typing
## act on the single thing under the pointer.
func _is_drag_tool() -> bool:
	return tool_mode in [GameEnums.ToolMode.WALL, GameEnums.ToolMode.FLOOR, GameEnums.ToolMode.DELETE]


# --- Preview ----------------------------------------------------------------

func _rebuild_preview() -> void:
	if not _world.has_hover():
		_clear_preview()
		return
	var to := _world.hovered_cell
	# A drag that started off-map has no anchor; fall back to a single cell
	# rather than building a rectangle that reaches outside the world.
	var from := _drag_start if _dragging and _world.grid.in_bounds(_drag_start) else to
	match tool_mode:
		GameEnums.ToolMode.WALL:
			_plan_wall_rect(from, to)
		GameEnums.ToolMode.FLOOR:
			_plan_floor_rect(from, to)
		GameEnums.ToolMode.DELETE:
			_plan_delete(from, to)
		GameEnums.ToolMode.DOOR:
			_plan_opening(GameEnums.EdgeType.DOOR)
		GameEnums.ToolMode.WINDOW:
			_plan_opening(GameEnums.EdgeType.WINDOW)
		GameEnums.ToolMode.ASSIGN_ROOM:
			_plan_assign_room()
		_:
			_clear_preview()


func _clear_preview() -> void:
	preview_cells = []
	preview_edges = []
	preview_cost = 0
	preview_valid = false


## Walls are placed around the perimeter of the dragged rectangle, which is the
## fastest way to get the closed rectangular rooms the MVP asks for. Interior
## partitions come from dragging a second rectangle against the first: the
## shared border is one edge, so the two rooms share one wall.
func _plan_wall_rect(from: Vector2i, to: Vector2i) -> void:
	preview_cells = []
	preview_edges = WorldGrid.rect_perimeter_edges(from, to)
	var new_walls := 0
	for edge in preview_edges:
		if _world.grid.get_edge(edge) == GameEnums.EdgeType.NONE:
			new_walls += 1
	preview_cost = new_walls * GameConstants.PRICE_WALL
	preview_valid = Economy.can_afford(preview_cost)


func _plan_floor_rect(from: Vector2i, to: Vector2i) -> void:
	preview_edges = []
	preview_cells = IsoUtils.cells_in_rect(from, to)
	var material := Database.get_floor(selected_floor_id)
	var price := material.price_per_tile if material != null else GameConstants.PRICE_FLOOR
	var changes := 0
	for cell in preview_cells:
		var data := _world.grid.get_cell(cell)
		if data == null or data.floor_id != selected_floor_id:
			changes += 1
	preview_cost = changes * price
	preview_valid = Economy.can_afford(preview_cost)


## Deleting is free, so the only thing to check is that something is there.
func _plan_delete(from: Vector2i, to: Vector2i) -> void:
	preview_cells = IsoUtils.cells_in_rect(from, to)
	preview_edges = []
	for edge in _all_edges_in_rect(from, to):
		if _world.grid.get_edge(edge) != GameEnums.EdgeType.NONE:
			preview_edges.append(edge)
	preview_cost = 0
	preview_valid = not preview_edges.is_empty() or _has_any_floor(preview_cells)


## A door or a window can only be cut into a wall that already exists.
func _plan_opening(type: int) -> void:
	preview_cells = []
	preview_edges = []
	var pointed: Variant = _pointed_edge()
	if pointed == null:
		preview_valid = false
		preview_cost = 0
		return
	var edge: Vector3i = pointed
	preview_edges = [edge]
	var current := _world.grid.get_edge(edge)
	preview_cost = GameConstants.PRICE_DOOR if type == GameEnums.EdgeType.DOOR else GameConstants.PRICE_WINDOW
	preview_valid = current != GameEnums.EdgeType.NONE and current != type and Economy.can_afford(preview_cost)


func _plan_assign_room() -> void:
	preview_edges = []
	preview_cost = 0
	var room := _room_under_pointer()
	preview_cells = room.cells if room != null else []
	preview_valid = room != null


# --- Apply ------------------------------------------------------------------

func _apply_drag() -> void:
	if not preview_valid:
		_reject_current()
		return
	match tool_mode:
		GameEnums.ToolMode.WALL:
			if not Economy.try_spend(preview_cost, "walls"):
				return
			for edge in preview_edges:
				if _world.grid.get_edge(edge) == GameEnums.EdgeType.NONE:
					_world.grid.set_edge(edge, GameEnums.EdgeType.WALL)
		GameEnums.ToolMode.FLOOR:
			if not Economy.try_spend(preview_cost, "flooring"):
				return
			for cell in preview_cells:
				_world.grid.set_floor_material(cell, selected_floor_id)
		GameEnums.ToolMode.DELETE:
			# Walls first: if the pointer covers both, removing the wall is
			# almost always what was meant.
			if not preview_edges.is_empty():
				for edge in preview_edges:
					_world.grid.set_edge(edge, GameEnums.EdgeType.NONE)
			else:
				for cell in preview_cells:
					_world.grid.set_floor_material(cell, &"")
	_clear_preview()


func _apply_click() -> void:
	if not preview_valid:
		_reject_current()
		return
	match tool_mode:
		GameEnums.ToolMode.DOOR, GameEnums.ToolMode.WINDOW:
			var type := GameEnums.EdgeType.DOOR if tool_mode == GameEnums.ToolMode.DOOR else GameEnums.EdgeType.WINDOW
			if not Economy.try_spend(preview_cost, "opening"):
				return
			_world.grid.set_edge(preview_edges[0], type)
		GameEnums.ToolMode.ASSIGN_ROOM:
			var room := _room_under_pointer()
			if room != null:
				_registry().set_room_type(room.id, selected_room_type)


## Tells the player *why* nothing happened, instead of appearing to be broken.
func _reject_current() -> void:
	var reason := "Nothing to build here"
	match tool_mode:
		GameEnums.ToolMode.DOOR, GameEnums.ToolMode.WINDOW:
			reason = "Point at an existing wall"
		GameEnums.ToolMode.ASSIGN_ROOM:
			reason = "Point inside an enclosed room"
		GameEnums.ToolMode.DELETE:
			reason = "Nothing here to remove"
	if preview_cost > 0 and not Economy.can_afford(preview_cost):
		reason = "Not enough money: $%d needed" % preview_cost
	EventBus.build_rejected.emit(reason)


# --- Geometry helpers -------------------------------------------------------

## Every edge touching a rectangle, used by the delete tool.
func _all_edges_in_rect(from: Vector2i, to: Vector2i) -> Array[Vector3i]:
	var edges: Array[Vector3i] = []
	var seen := {}
	for cell in IsoUtils.cells_in_rect(from, to):
		for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var edge := WorldGrid.edge_key(cell, direction)
			if not seen.has(edge):
				seen[edge] = true
				edges.append(edge)
	return edges


## Which cell border is the pointer nearest to, or null when it is in open floor.
## Works in fractional cell space, so it is resolution and zoom independent.
func _pointed_edge() -> Variant:
	if not _world.has_hover():
		return null
	var local := IsoUtils.world_to_cell_f(_world.get_global_mouse_position())
	var cell := _world.hovered_cell
	var fx := local.x - float(cell.x)
	var fy := local.y - float(cell.y)
	var distances := {
		Vector2i.UP: fy,
		Vector2i.DOWN: 1.0 - fy,
		Vector2i.LEFT: fx,
		Vector2i.RIGHT: 1.0 - fx,
	}
	var best_direction := Vector2i.UP
	var best := 2.0
	for direction: Vector2i in distances:
		var distance: float = distances[direction]
		if distance < best:
			best = distance
			best_direction = direction
	if best > EDGE_PICK_THRESHOLD:
		return null
	return WorldGrid.edge_key(cell, best_direction)


func _has_any_floor(cells: Array[Vector2i]) -> bool:
	for cell in cells:
		var data := _world.grid.get_cell(cell)
		if data != null and data.floor_id != &"":
			return true
	return false


func _room_under_pointer() -> Room:
	if not _world.has_hover():
		return null
	return _registry().room_at(_world.hovered_cell)


func _registry() -> BuildingRegistry:
	return _world.get_node("Buildings") as BuildingRegistry
