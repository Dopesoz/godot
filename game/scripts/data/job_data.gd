class_name JobData
extends GameData

## A profession (design doc §19): salary, working hours and the kind of building
## the citizen commutes to.

@export var salary_per_day: int = 100

## Working hours in game hours, 0..24. `start_hour` may be greater than
## `end_hour` for night shifts.
@export_range(0.0, 24.0) var start_hour: float = 9.0
@export_range(0.0, 24.0) var end_hour: float = 18.0

## Days of the week this job is worked. 0 = Monday.
@export var work_days: Array[int] = [0, 1, 2, 3, 4]

## Where the citizen goes to work.
@export var workplace_building_type: GameEnums.BuildingType = GameEnums.BuildingType.COMMERCIAL

## Optional: a specific room type inside the workplace (e.g. CLASSROOM).
@export var workplace_room_type: GameEnums.RoomType = GameEnums.RoomType.UNDEFINED

## Skill the employer pays for. Levels in it raise this job's wage through
## SkillData.wage_bonus_per_level.
@export var skill_id: StringName = &""

## How many citizens one workplace of this type can employ.
@export var slots_per_workplace: int = 4


func is_working_hour(hour: float) -> bool:
	if start_hour <= end_hour:
		return hour >= start_hour and hour < end_hour
	# Night shift wrapping past midnight.
	return hour >= start_hour or hour < end_hour


func is_working_day(day_of_week: int) -> bool:
	return work_days.has(day_of_week)
