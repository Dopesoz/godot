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

const NAME_LABEL_MIN_ZOOM := 1.2

var _grid: WorldGrid
var _furniture: FurnitureRegistry
var _citizens: CitizenRegistry
var _camera: CameraRig
var _font: Font

## Cached {depth, kind, ref} entries for the things that rarely change.
var _static_entries: Array = []
var _static_dirty: bool = true


func _ready() -> void:
	_font = ThemeDB.fallback_font
	_furniture = get_parent().get_node_or_null("Furniture") as FurnitureRegistry
	_citizens = get_parent().get_node_or_null("Citizens") as CitizenRegistry
	_camera = get_parent().get_node_or_null("CameraRig") as CameraRig

	EventBus.world_ready.connect(_on_world_ready)
	EventBus.edge_changed.connect(_on_static_changed)
	EventBus.furniture_placed.connect(_on_static_changed)
	EventBus.furniture_removed.connect(_on_static_changed)
	EventBus.citizen_spawned.connect(_on_static_changed)
	EventBus.citizen_removed.connect(_on_static_changed)
	EventBus.citizen_state_changed.connect(_on_static_changed)
	# Windows glow after dark, so the pass is repainted when the light moves.
	EventBus.daylight_changed.connect(_on_static_changed)


func _on_world_ready(world: WorldGrid) -> void:
	_grid = world
	_static_dirty = true
	queue_redraw()


func _on_static_changed(_a: Variant = null, _b: Variant = null) -> void:
	_static_dirty = true
	queue_redraw()


func _process(_delta: float) -> void:
	# Redraw only when something can actually have moved.
	if _citizens != null and _citizens.count() > 0 and not GameClock.is_paused():
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

	var show_names := _camera == null or _camera.get_target_zoom() >= NAME_LABEL_MIN_ZOOM
	for entry: Dictionary in entries:
		match entry["kind"]:
			"edge":
				Painters.draw_edge(self, entry["ref"], int(entry["type"]))
			"furniture":
				Painters.draw_furniture(self, entry["ref"])
			"citizen":
				Painters.draw_citizen(self, entry["ref"], _font, show_names)


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
		})
	if _furniture != null:
		for item: Furniture in _furniture.items.values():
			var centre := item.center()
			_static_entries.append({
				"depth": centre.x + centre.y,
				"kind": "furniture",
				"ref": item,
			})
