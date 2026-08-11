extends CanvasLayer

## Minimal HUD for Phase 1: clock, money, and a debug readout (F3).
##
## Reads the model, never writes to it except through the services' own public
## commands (pausing the clock). Phase 13 replaces the look; the wiring stays.

@onready var _clock_label: Label = %ClockLabel
@onready var _money_label: Label = %MoneyLabel
@onready var _debug_label: Label = %DebugLabel
@onready var _hint_label: Label = %HintLabel

var _world: WorldController
var _camera: CameraRig


func _ready() -> void:
	# The HUD lives under the world scene, so its owner is the world root.
	_world = get_tree().get_first_node_in_group(&"world") as WorldController
	if _world != null:
		_camera = _world.camera
	EventBus.money_changed.connect(_on_money_changed)
	EventBus.minute_passed.connect(_on_minute_passed)
	_on_money_changed(Economy.money, 0)
	_on_minute_passed(GameClock.hour, GameClock.minute)
	_debug_label.visible = OS.is_debug_build()
	_hint_label.text = "WASD / arrows — move    wheel — zoom    middle drag — pan    one finger — pan    two fingers — zoom    G — grid    Space — pause    +/− — speed    F3 — debug    M — music"


func _process(_delta: float) -> void:
	if not _debug_label.visible:
		return
	var cell_text := "—"
	if _world != null and _world.has_hover():
		cell_text = "%d, %d" % [_world.hovered_cell.x, _world.hovered_cell.y]
	var residents := 0
	if _world != null:
		var registry := _world.get_node_or_null("Citizens") as CitizenRegistry
		residents = registry.count() if registry != null else 0
	_debug_label.text = "cell %s    zoom %.2fx    %d fps    residents %d    sim agents %d (full %d / reduced %d / abstract %d)" % [
		cell_text,
		_camera.get_target_zoom() if _camera != null else 0.0,
		Engine.get_frames_per_second(),
		residents,
		SimScheduler.agent_count(),
		SimScheduler.counts[GameEnums.SimLOD.FULL],
		SimScheduler.counts[GameEnums.SimLOD.REDUCED],
		SimScheduler.counts[GameEnums.SimLOD.ABSTRACT],
	]


func _unhandled_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed(InputActions.TOGGLE_DEBUG):
		_debug_label.visible = not _debug_label.visible
	elif Input.is_action_just_pressed(InputActions.TOGGLE_MUTE):
		AudioManager.toggle_mute()


func _on_money_changed(amount: int, _delta: int) -> void:
	_money_label.text = "$ %s" % _thousands(amount)


func _on_minute_passed(_hour: int, _minute: int) -> void:
	var speed := GameClock.get_speed()
	var suffix := "  ‖ paused" if speed <= 0.0 else "  x%d" % int(speed)
	_clock_label.text = GameClock.format_time() + suffix


static func _thousands(value: int) -> String:
	var text := str(absi(value))
	var out := ""
	var count := 0
	for i in range(text.length() - 1, -1, -1):
		out = text[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = " " + out
	return ("-" if value < 0 else "") + out
