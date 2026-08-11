class_name ScheduleData
extends GameData

## A daily routine (design doc §18), kept as its own module and its own data
## file rather than as code inside the AI.
##
## A schedule does NOT command the citizen. It bends what already exists: each
## entry says which needs matter more during which hours, and DecisionMaker
## multiplies its urgency by that. So at 23:00 sleep becomes urgent long before
## energy actually runs out, and at 08:00 breakfast beats the television —
## without anyone hard-coding "go to bed at 23:00".
##
## The reason for doing it this way rather than as a list of commands: a
## commanded citizen looks broken the moment reality disagrees with the plan
## (the bed is taken, the kitchen is unreachable, they are starving at 3am). A
## biased citizen simply weighs things differently and keeps behaving sensibly.

## Blocks of the day. Overlapping entries multiply, which is what lets a general
## "evening" block coexist with a specific "dinner" block.
@export var entries: Array[ScheduleEntry] = []


## Need -> multiplier at this hour. Needs not mentioned default to 1.0.
func weights_at(hour: float) -> Dictionary:
	var weights := {}
	for entry in entries:
		if entry == null or not entry.covers(hour):
			continue
		for need_type: int in entry.need_weights:
			var current: float = weights.get(need_type, 1.0)
			weights[need_type] = current * float(entry.need_weights[need_type])
	return weights


func weight_for(need_type: int, hour: float) -> float:
	var weight := 1.0
	for entry in entries:
		if entry == null or not entry.covers(hour):
			continue
		weight *= float(entry.need_weights.get(need_type, 1.0))
	return weight


## What the routine calls this part of the day, for the inspector.
func label_at(hour: float) -> String:
	for entry in entries:
		if entry != null and entry.covers(hour) and entry.label != "":
			return entry.label
	return ""
