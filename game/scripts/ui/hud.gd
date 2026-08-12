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
	# Not _world.camera: the HUD is a child of the world scene, so its _ready
	# runs before the world's own @onready assignments. Looked up by node
	# instead, which is valid at this point.
	_camera = _world.get_node_or_null("CameraRig") as CameraRig if _world != null else null
	EventBus.city_event_started.connect(_on_city_event)
	EventBus.city_event_ended.connect(_on_city_event)
	EventBus.money_changed.connect(_on_money_changed)
	EventBus.minute_passed.connect(_on_minute_passed)
	_on_money_changed(Economy.money, 0)
	_on_minute_passed(GameClock.hour, GameClock.minute)
	_debug_label.visible = OS.is_debug_build()
	_hint_label.text = _controls_hint()
	_scale_text()


## The clock and the money are the two numbers a player actually reads, and on a
## phone they were being drawn at desktop size on a screen held at arm's length.
## Each label is scaled from whatever the theme gives it, so the scene keeps
## deciding the relative sizes and this only decides how big "big" is.
func _scale_text() -> void:
	var scale := Platform.ui_scale()
	if is_equal_approx(scale, 1.0):
		return
	for label: Label in [_clock_label, _money_label, _hint_label, _debug_label]:
		var base := label.get_theme_font_size(&"font_size")
		label.add_theme_font_size_override(&"font_size", roundi(float(base) * scale))


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


## What the city is going through, kept in the corner rather than as a popup:
## an event lasts hours, and a modal would interrupt the thing the player is
## actually watching.
func _on_city_event(_a: Variant = null, _b: Variant = null) -> void:
	var names := CityEvents.active_names()
	_hint_label.text = ("• " + "   •  ".join(names)) if not names.is_empty() else _controls_hint()


func _controls_hint() -> String:
	# One line, and it has to stay one line: wrapped onto two it pushes the
	# clock around. So a phone is told about fingers and a desktop about keys,
	# instead of both being told about both.
	if Platform.has_touch():
		return "one finger — pan    two fingers — zoom    tap a resident to follow them"
	return "WASD — move    wheel — zoom    E — walls    G — grid    Space — pause    +/− — speed    F3 — debug    M — music"


func _on_money_changed(amount: int, _delta: int) -> void:
	# The balance alone hides whether the city is sustainable; the daily net is
	# the number that actually matters.
	var net := Economy.daily_income() - Economy.daily_upkeep()
	var suffix := "  (%s%d/day)" % ["+" if net >= 0 else "", net]
	_money_label.text = "$ %s%s" % [_thousands(amount), suffix]


func _on_minute_passed(_hour: int, _minute: int) -> void:
	var speed := GameClock.get_speed()
	var suffix := "  ‖ paused" if speed <= 0.0 else "  x%d" % int(speed)
	var phase := "night" if GameClock.is_night() else "day"
	_clock_label.text = "%s  %s%s" % [GameClock.format_time(), phase, suffix]


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
