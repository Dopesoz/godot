extends Node2D

## One depth-sorted pass over everything that stands on the map.
##
## Phase 2 and 3 drew walls and furniture in separate layers, which is fine
## until something moves: a citizen walking behind a wall has to be hidden by
## it, and the same citizen one cell further south has to be drawn on top. That
## ordering cannot be expressed by layer order, only by depth — so walls,
## furniture and citizens are collected here, sorted by their position along the
## screen's depth axis (x + y), and drawn back to front into one canvas item.
##
## Cost control: walls and furniture change rarely, so their entries are cached
## and only rebuilt when something is actually built or removed. Citizens are
## collected fresh each frame — but only while at least one of them is moving,
## so a paused or empty city redraws nothing at all.

## How much of a building the camera is allowed to hide.
##
## The whole premise is that the player looks *inside* a house (design doc §34),
## and a fixed isometric camera puts two of every room's four walls between the
## viewer and the people living there. So by default those two are cut down to
## a stub — the room stays enclosed in the simulation, it is only drawn short.
## The other two modes exist because "how does my house look from outside" and
## "let me see the whole floor plan" are both fair questions.
enum WallMode {
	CUTAWAY, ## Walls in front of a room are cut down; walls behind stay full.
	FULL,    ## Every wall at full height — the outside view.
	LOW,     ## Every wall cut down — the floor-plan view.
}

const WALL_MODE_NAMES := {
	WallMode.CUTAWAY: "Walls: cutaway",
	WallMode.FULL: "Walls: full",
	WallMode.LOW: "Walls: down",
}

var _wall_mode: WallMode = WallMode.CUTAWAY

var _grid: WorldGrid
var _furniture: FurnitureRegistry
var _citizens: CitizenRegistry
var _font: Font

## Cached {depth, kind, ref} entries for the things that rarely change.
var _static_entries: Array = []
var _static_dirty: bool = true
var _selected_id: int = -1


func _ready() -> void:
	_font = ThemeDB.fallback_font
	# Sprites are authored at twice their drawn size; mipmaps are what keeps
	# that from shimmering as the camera moves.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_furniture = get_parent().get_node_or_null("Furniture") as FurnitureRegistry
	_citizens = get_parent().get_node_or_null("Citizens") as CitizenRegistry

	EventBus.world_ready.connect(_on_world_ready)
	EventBus.edge_changed.connect(_on_static_changed)
	EventBus.furniture_placed.connect(_on_static_changed)
	EventBus.furniture_removed.connect(_on_static_changed)
	EventBus.citizen_spawned.connect(_on_static_changed)
	EventBus.citizen_removed.connect(_on_static_changed)
	EventBus.citizen_state_changed.connect(_on_static_changed)
	# Windows glow after dark, so the pass is repainted when the light moves.
	EventBus.daylight_changed.connect(_on_static_changed)
	# Which walls hide an interior depends on where the rooms are.
	EventBus.rooms_rebuilt.connect(_on_static_changed)
	EventBus.selection_changed.connect(_on_selection_changed)


## Asks the event rather than polling Input: a press and its release can arrive
## in the same frame, and `is_action_just_pressed` would then fire for both.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(InputActions.WALL_MODE):
		return
	_wall_mode = ((_wall_mode + 1) % WallMode.size()) as WallMode
	_static_dirty = true
	queue_redraw()
	EventBus.notify(WALL_MODE_NAMES[_wall_mode])


func _on_selection_changed(selected: Variant) -> void:
	var citizen := selected as Citizen
	_selected_id = citizen.id if citizen != null else -1
	queue_redraw()


func _on_world_ready(world: WorldGrid) -> void:
	_grid = world
	_static_dirty = true
	queue_redraw()


func _on_static_changed(_a: Variant = null, _b: Variant = null) -> void:
	_static_dirty = true
	queue_redraw()


func _process(_delta: float) -> void:
	# Redraw only when something can actually have moved.
	# Animation continues while paused — a pulsing "in use" outline and a
	# selection ring should not freeze just because time did.
	if (_citizens != null and _citizens.count() > 0) or _furniture_in_use():
		queue_redraw()


func _draw() -> void:
	if _grid == null:
		return
	if _static_dirty:
		_rebuild_static()
		_static_dirty = false

	var entries := _static_entries.duplicate()
	if _citizens != null:
		for citizen: Citizen in _citizens.all():
			entries.append({
				"depth": citizen.position.x + citizen.position.y + 0.25,
				"kind": "citizen",
				"ref": citizen,
			})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["depth"]) < float(b["depth"]))

	for entry: Dictionary in entries:
		match entry["kind"]:
			"edge":
				Painters.draw_edge(self, entry["ref"], int(entry["type"]), 0, bool(entry["cut"]))
			"furniture":
				Painters.draw_furniture(self, entry["ref"])
			"citizen":
				var citizen: Citizen = entry["ref"]
				var selected := citizen.id == _selected_id
				# Only the selected resident is named. Labels are drawn in world
				# space, so at close zoom every name became a banner across the
				# room it was in; the emote over the head says what matters
				# anyway, and clicking says who.
				Painters.draw_citizen(self, citizen, _font, selected, selected)


## Is this wall standing between the camera and a room?
##
## The camera looks along +x +y, so of the two cells an edge separates, the one
## with the *lower* coordinate is behind it. If that far cell belongs to a room,
## this wall is what the player would be staring at instead of the room, and it
## gets cut down. Walls with the room in front of them are left alone: those are
## the back walls, and they are what makes the house look like a house.
func _is_cut_away(edge: Vector3i) -> bool:
	match _wall_mode:
		WallMode.FULL:
			return false
		WallMode.LOW:
			return true
	var behind := Vector2i(edge.x, edge.y)
	if edge.z == GameEnums.EdgeAxis.HORIZONTAL:
		behind.y -= 1
	else:
		behind.x -= 1
	return _grid.room_of(behind) != -1


func _furniture_in_use() -> bool:
	if _furniture == null:
		return false
	for item: Furniture in _furniture.items.values():
		if not item.users.is_empty():
			return true
	return false


## Depth conventions, all in cell units along the x + y axis:
##   a horizontal edge sits on its cell's northern border  -> x + y
##   a vertical edge sits half a step further back         -> x + y + 0.5
##   furniture is centred in its footprint                 -> centre.x + centre.y
##   a citizen stands slightly in front of the furniture they are using
func _rebuild_static() -> void:
	_static_entries.clear()
	for edge: Vector3i in _grid.used_edges():
		_static_entries.append({
			"depth": float(edge.x + edge.y) + (0.0 if edge.z == GameEnums.EdgeAxis.HORIZONTAL else 0.5),
			"kind": "edge",
			"ref": edge,
			"type": _grid.get_edge(edge),
			"cut": _is_cut_away(edge),
		})
	if _furniture != null:
		for item: Furniture in _furniture.items.values():
			var centre := item.center()
			_static_entries.append({
				"depth": centre.x + centre.y,
				"kind": "furniture",
				"ref": item,
			})
