extends Node

## Touch adapter: one-finger drag pans, two-finger pinch zooms.
##
## Brought forward from Phase 12 because Android is the target platform and the
## game should be testable on a phone from now on. It is the proof that the
## camera API was worth having: this file drives the exact same
## `pan_screen` / `zoom_at` calls the desktop adapter uses, and no game logic
## knows the difference.
##
## Godot synthesises mouse events from the first finger, so tapping already
## reaches the build tools. This adapter therefore only has to answer one
## question: is this gesture meant to move the camera, or to build?
##   - two fingers      -> always the camera (pinch/pan)
##   - one finger, no active build tool -> camera pan
##   - one finger, build tool active    -> left alone, so the tap or drag
##                                          becomes a build action
##
## The node is harmless on desktop: without touch events it never does anything.

@export var camera_path: NodePath = NodePath("../CameraRig")
@export var builder_path: NodePath = NodePath("../Builder")

## Fingers currently down: touch index -> last known screen position.
var _touches: Dictionary = {}
## Distance between the two fingers on the previous frame of a pinch.
var _pinch_distance: float = 0.0

@onready var _camera: CameraRig = get_node_or_null(camera_path)
@onready var _builder: BuildController = get_node_or_null(builder_path)


func _ready() -> void:
	if _camera == null:
		push_error("TouchInputAdapter: no CameraRig at '%s'" % camera_path)
		set_process_unhandled_input(false)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_on_drag(event as InputEventScreenDrag)


func _on_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touches[event.index] = event.position
	else:
		_touches.erase(event.index)
	# Reset the pinch baseline whenever the number of fingers changes, otherwise
	# lifting one finger of two would register as a huge sudden zoom.
	_pinch_distance = 0.0


func _on_drag(event: InputEventScreenDrag) -> void:
	_touches[event.index] = event.position
	if _touches.size() >= 2:
		_pinch()
		return
	if _is_build_gesture():
		return
	_camera.pan_screen(event.relative)


## Pinch: the change in finger separation is the zoom factor, and the midpoint
## is the anchor, so the map appears to stretch between the fingers.
func _pinch() -> void:
	var positions: Array = _touches.values()
	var a: Vector2 = positions[0]
	var b: Vector2 = positions[1]
	var distance := a.distance_to(b)
	if distance <= 1.0:
		return
	if _pinch_distance > 1.0:
		_camera.zoom_at(distance / _pinch_distance, (a + b) * 0.5)
	_pinch_distance = distance


func _is_build_gesture() -> bool:
	return _builder != null and _builder.is_building()
