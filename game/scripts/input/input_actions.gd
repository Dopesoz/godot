class_name InputActions
extends RefCounted

## Registers input actions in code instead of in project.godot.
##
## Why: the desktop build and the Android build want different bindings, and the
## game will let the player rebind later. Declaring them here means one place to
## read, one place to change, and no merge conflicts inside project.godot.
##
## Gameplay code never reads raw keys — it reads these action names through an
## input adapter (Phase 1 for desktop, Phase 12 for touch), so adding gestures
## later touches no game logic.

const CAMERA_UP := &"camera_up"
const CAMERA_DOWN := &"camera_down"
const CAMERA_LEFT := &"camera_left"
const CAMERA_RIGHT := &"camera_right"
const CAMERA_ZOOM_IN := &"camera_zoom_in"
const CAMERA_ZOOM_OUT := &"camera_zoom_out"
const CAMERA_DRAG := &"camera_drag"

const BUILD_CONFIRM := &"build_confirm"
const BUILD_CANCEL := &"build_cancel"
const BUILD_ROTATE := &"build_rotate"

const TIME_PAUSE := &"time_pause"
const TIME_FASTER := &"time_faster"
const TIME_SLOWER := &"time_slower"

const WALL_MODE := &"wall_mode"
const TOGGLE_GRID := &"toggle_grid"
const TOGGLE_DEBUG := &"toggle_debug"
const TOGGLE_MUTE := &"toggle_mute"


static func ensure_default_actions() -> void:
	_key_action(CAMERA_UP, [KEY_W, KEY_UP])
	_key_action(CAMERA_DOWN, [KEY_S, KEY_DOWN])
	_key_action(CAMERA_LEFT, [KEY_A, KEY_LEFT])
	_key_action(CAMERA_RIGHT, [KEY_D, KEY_RIGHT])
	_key_action(BUILD_ROTATE, [KEY_R])
	_key_action(BUILD_CANCEL, [KEY_ESCAPE])
	_key_action(TIME_PAUSE, [KEY_SPACE])
	_key_action(TIME_FASTER, [KEY_EQUAL, KEY_KP_ADD])
	_key_action(TIME_SLOWER, [KEY_MINUS, KEY_KP_SUBTRACT])
	_key_action(WALL_MODE, [KEY_E])
	_key_action(TOGGLE_GRID, [KEY_G])
	_key_action(TOGGLE_DEBUG, [KEY_F3])
	_key_action(TOGGLE_MUTE, [KEY_M])

	_mouse_action(BUILD_CONFIRM, MOUSE_BUTTON_LEFT)
	_mouse_action(CAMERA_DRAG, MOUSE_BUTTON_MIDDLE)
	_mouse_action(CAMERA_ZOOM_IN, MOUSE_BUTTON_WHEEL_UP)
	_mouse_action(CAMERA_ZOOM_OUT, MOUSE_BUTTON_WHEEL_DOWN)


## Idempotent: re-running it after a rebind wipes the old events for that action
## only, never the whole InputMap.
static func _key_action(action: StringName, keys: Array) -> void:
	_reset(action)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)


static func _mouse_action(action: StringName, button: int) -> void:
	_reset(action)
	var event := InputEventMouseButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)


static func _reset(action: StringName) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	else:
		InputMap.action_erase_events(action)


## Touch profile placeholder. Phase 12 fills this in; the constant names above
## stay the same, which is the whole point of this indirection.
static func is_touch_platform() -> bool:
	return OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
