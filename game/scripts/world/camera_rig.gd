class_name CameraRig
extends Camera2D

## The camera. Exposes intent ("pan by this much", "zoom towards this point")
## and knows nothing about keyboards, mouse wheels or pinch gestures — those
## live in input adapters (scripts/input/). Phase 12 adds a touch adapter and
## does not touch this file.
##
## Movement is smoothed by moving a *target* and easing the real transform
## towards it, so a mouse wheel notch, a key hold and a two-finger pinch all
## feel the same.

## Where the camera wants to be. The node eases towards it every frame.
var _target_position: Vector2 = Vector2.ZERO
var _target_zoom: float = GameConstants.CAMERA_ZOOM_DEFAULT

## World-space rectangle the view is kept inside, built from the map corners.
var _bounds: Rect2 = Rect2()

var _last_focus_cell: Vector2i = Vector2i(-9999, -9999)


func _ready() -> void:
	_target_zoom = GameConstants.CAMERA_ZOOM_DEFAULT
	zoom = Vector2.ONE * _target_zoom
	_target_position = position
	set_bounds_from_map(GameConstants.MAP_SIZE)


## The four map corners projected to pixels give the diamond's bounding box.
## Padding of one tile keeps the outermost tiles from touching the screen edge.
func set_bounds_from_map(map_size: Vector2i) -> void:
	var corners := [
		IsoUtils.cell_to_world(Vector2i(0, 0)),
		IsoUtils.cell_to_world(Vector2i(map_size.x - 1, 0)),
		IsoUtils.cell_to_world(Vector2i(0, map_size.y - 1)),
		IsoUtils.cell_to_world(Vector2i(map_size.x - 1, map_size.y - 1)),
	]
	var top_left := Vector2(INF, INF)
	var bottom_right := Vector2(-INF, -INF)
	for corner: Vector2 in corners:
		top_left = top_left.min(corner)
		bottom_right = bottom_right.max(corner)
	var pad := Vector2(GameConstants.TILE_W, GameConstants.TILE_H)
	_bounds = Rect2(top_left - pad, bottom_right - top_left + pad * 2.0)
	_target_position = _clamp_to_bounds(_target_position, _target_zoom)


# --- Commands (this is the whole public API input adapters may use) ---------

## Move by a screen-space delta, e.g. how far a finger or the mouse dragged.
## Divided by zoom so dragging always moves the world by the same number of
## pixels under the pointer, at any zoom level.
func pan_screen(delta_screen: Vector2) -> void:
	pan_world(-delta_screen / _target_zoom)


func pan_world(delta_world: Vector2) -> void:
	_target_position = _clamp_to_bounds(_target_position + delta_world, _target_zoom)


## Zoom by a multiplier while keeping the world point under `screen_point`
## fixed. That is what makes wheel zoom and pinch feel right.
func zoom_at(factor: float, screen_point: Vector2) -> void:
	var new_zoom := clampf(_target_zoom * factor, GameConstants.CAMERA_ZOOM_MIN, GameConstants.CAMERA_ZOOM_MAX)
	if is_equal_approx(new_zoom, _target_zoom):
		return
	var from_center := screen_point - get_viewport_rect().size * 0.5
	# The same screen offset covers less world as we zoom in; shift the target
	# by the difference so the point under the cursor stays put.
	_target_position += from_center / _target_zoom - from_center / new_zoom
	_target_zoom = new_zoom
	_target_position = _clamp_to_bounds(_target_position, _target_zoom)


func zoom_by(factor: float) -> void:
	zoom_at(factor, get_viewport_rect().size * 0.5)


func focus_cell(cell: Vector2i, instant: bool = false) -> void:
	_target_position = _clamp_to_bounds(IsoUtils.cell_to_world(cell), _target_zoom)
	if instant:
		position = _target_position


func get_target_zoom() -> float:
	return _target_zoom


## Which cell the camera is looking at. SimScheduler uses it to pick who gets
## simulated in full detail.
func focused_cell() -> Vector2i:
	return IsoUtils.world_to_cell(position)


func _process(delta: float) -> void:
	# Frame-rate independent easing: the same feel at 30 and at 144 fps.
	var weight := 1.0 - exp(-GameConstants.CAMERA_PAN_SMOOTHING * delta)
	position = position.lerp(_target_position, weight)
	zoom = zoom.lerp(Vector2.ONE * _target_zoom, weight)

	# Tell the simulation where the player is looking, but only when it changes
	# cell — SimScheduler re-sorts its agents on this value.
	var cell := focused_cell()
	if cell != _last_focus_cell:
		_last_focus_cell = cell
		SimScheduler.set_focus_cell(cell)


## Keeps the visible rectangle inside the map. When the map is smaller than the
## screen on an axis, the camera is centred on that axis instead of clamped —
## otherwise it would jitter between two impossible limits.
func _clamp_to_bounds(candidate: Vector2, at_zoom: float) -> Vector2:
	if _bounds.size == Vector2.ZERO:
		return candidate
	var half := get_viewport_rect().size * 0.5 / at_zoom
	var result := candidate
	if _bounds.size.x <= half.x * 2.0:
		result.x = _bounds.position.x + _bounds.size.x * 0.5
	else:
		result.x = clampf(result.x, _bounds.position.x + half.x, _bounds.end.x - half.x)
	if _bounds.size.y <= half.y * 2.0:
		result.y = _bounds.position.y + _bounds.size.y * 0.5
	else:
		result.y = clampf(result.y, _bounds.position.y + half.y, _bounds.end.y - half.y)
	return result
