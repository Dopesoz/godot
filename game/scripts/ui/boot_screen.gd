extends Control

## Phase 0 entry point.
##
## Runs the architecture self-test, shows the result, and keeps a live readout of
## the clock and the simulation scheduler so it is obvious at a glance that the
## services are running rather than merely instantiated.
##
## Once every check passes it hands over to the world scene. A failed check
## keeps the report on screen instead — booting into a broken world would hide
## the real cause behind whatever breaks next.

const WORLD_SCENE := "res://scenes/world/world.tscn"
const HANDOVER_DELAY := 1.5

@onready var _report: RichTextLabel = %Report
@onready var _status: Label = %Status
@onready var _live: Label = %Live

var _probe: ArchitectureCheck.ProbeAgent
var _results: Array[ArchitectureCheck.Result] = []


func _ready() -> void:
	InputActions.ensure_default_actions()

	_probe = ArchitectureCheck.ProbeAgent.new()
	SimScheduler.register(_probe)

	_results = ArchitectureCheck.run_all()
	_render()

	# The scheduler needs a few frames to deliver ticks, so its check runs last.
	await get_tree().create_timer(1.0).timeout
	_results.append(ArchitectureCheck.check_scheduler(_probe, 3))
	_results.append(ArchitectureCheck.check_room_type_persistence())
	_results.append(ArchitectureCheck.check_furniture_placement())
	_render()

	# Headless mode for CI: `godot --headless -- --selftest` prints the report
	# and exits non-zero if anything failed.
	if OS.get_cmdline_user_args().has("--selftest"):
		_print_report_and_quit()
		return

	if _all_passed():
		_status.text += "  —  entering the world…"
		await get_tree().create_timer(HANDOVER_DELAY).timeout
		SimScheduler.unregister(_probe)
		get_tree().change_scene_to_file(WORLD_SCENE)


func _all_passed() -> bool:
	for result in _results:
		if not result.ok:
			return false
	return true


func _print_report_and_quit() -> void:
	var failed := 0
	for result in _results:
		if not result.ok:
			failed += 1
		print("%s  %s — %s" % ["PASS" if result.ok else "FAIL", result.name, result.detail])
	print("%d/%d checks passed" % [_results.size() - failed, _results.size()])
	get_tree().quit(0 if failed == 0 else 1)


func _process(_delta: float) -> void:
	if _live == null:
		return
	_live.text = "%s   speed x%s   daylight %d%%   money %d   sim agents %d (full %d / reduced %d / abstract %d)" % [
		GameClock.format_time(),
		GameClock.get_speed(),
		roundi(GameClock.get_daylight() * 100.0),
		Economy.money,
		SimScheduler.agent_count(),
		SimScheduler.counts[GameEnums.SimLOD.FULL],
		SimScheduler.counts[GameEnums.SimLOD.REDUCED],
		SimScheduler.counts[GameEnums.SimLOD.ABSTRACT],
	]


func _unhandled_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed(InputActions.TIME_PAUSE):
		GameClock.toggle_pause()
	elif Input.is_action_just_pressed(InputActions.TIME_FASTER):
		GameClock.set_speed_index(GameClock.speed_index + 1)
	elif Input.is_action_just_pressed(InputActions.TIME_SLOWER):
		GameClock.set_speed_index(GameClock.speed_index - 1)


func _render() -> void:
	var passed := 0
	var lines := PackedStringArray()
	for result in _results:
		if result.ok:
			passed += 1
			lines.append("[color=#6ee7a0]  PASS[/color]  %s [color=#8a8f99]— %s[/color]" % [result.name, result.detail])
		else:
			lines.append("[color=#ff7b72]  FAIL[/color]  %s [color=#ffb4ae]— %s[/color]" % [result.name, result.detail])
	_report.text = "\n".join(lines)

	var total := _results.size()
	if passed == total:
		_status.text = "PHASE 0 — architecture online (%d/%d checks passed)" % [passed, total]
		_status.add_theme_color_override("font_color", Color(0.43, 0.91, 0.63))
	else:
		_status.text = "PHASE 0 — %d of %d checks passed" % [passed, total]
		_status.add_theme_color_override("font_color", Color(1.0, 0.48, 0.45))
