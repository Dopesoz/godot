extends Node

## Desktop input adapter: keyboard, mouse wheel, middle-drag.
##
## The only thing in the project that reads raw input for the camera. It
## translates hardware events into CameraRig commands (`pan_screen`, `zoom_at`).
## The touch adapter added in Phase 12 will emit the exact same commands from
## drag and pinch gestures, and nothing else in the game will change.

@export var camera_path: NodePath = NodePath("../CameraRig")

@onready var _camera: CameraRig = get_node_or_null(camera_path)

var _dragging: bool = false


func _ready() -> void:
	InputActions.ensure_default_actions()
	if _camera == null:
		push_error("DesktopInputAdapter: no CameraRig at '%s'" % camera_path)
		set_process(false)
		set_process_unhandled_input(false)


func _process(delta: float) -> void:
	var direction := Vector2(
		Input.get_axis(InputActions.CAMERA_LEFT, InputActions.CAMERA_RIGHT),
		Input.get_axis(InputActions.CAMERA_UP, InputActions.CAMERA_DOWN)
	)
	if direction == Vector2.ZERO:
		return
	# Divided by zoom so keyboard panning covers the same amount of *world* per
	# second whether zoomed in or out.
	_camera.pan_world(direction.normalized() * GameConstants.CAMERA_KEYBOARD_SPEED * delta / _camera.get_target_zoom())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
			_camera.zoom_at(GameConstants.CAMERA_ZOOM_STEP, button.position)
			get_viewport().set_input_as_handled()
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
			_camera.zoom_at(1.0 / GameConstants.CAMERA_ZOOM_STEP, button.position)
			get_viewport().set_input_as_handled()
		elif button.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = button.pressed
	elif event is InputEventMouseMotion and _dragging:
		_camera.pan_screen((event as InputEventMouseMotion).relative)

	if Input.is_action_just_pressed(InputActions.TIME_PAUSE):
		GameClock.toggle_pause()
	elif Input.is_action_just_pressed(InputActions.TIME_FASTER):
		GameClock.set_speed_index(GameClock.speed_index + 1)
	elif Input.is_action_just_pressed(InputActions.TIME_SLOWER):
		GameClock.set_speed_index(GameClock.speed_index - 1)
