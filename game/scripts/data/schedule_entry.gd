class_name ScheduleEntry
extends Resource

## One block of a daily routine: "22:30–07:00, sleep matters three times as
## much". Part of ScheduleData; see that file for why schedules bias rather
## than command.

@export var label: String = ""

## Hours of the day, 0..24. `start_hour` may be greater than `end_hour` for a
## block that runs through midnight.
@export_range(0.0, 24.0) var start_hour: float = 0.0
@export_range(0.0, 24.0) var end_hour: float = 24.0

## NeedType -> multiplier applied to that need's urgency during this block.
## Above 1.0 makes it pressing, below 1.0 tells the citizen it can wait.
@export var need_weights: Dictionary = {}


func covers(hour: float) -> bool:
	if is_equal_approx(start_hour, end_hour):
		return false
	if start_hour < end_hour:
		return hour >= start_hour and hour < end_hour
	# Wraps past midnight: 22:30–07:00 covers both 23:00 and 03:00.
	return hour >= start_hour or hour < end_hour
