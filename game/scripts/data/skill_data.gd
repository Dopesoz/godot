class_name SkillData
extends GameData

## Something a citizen gets better at by doing it (cooking, fitness, music…).
##
## Skills exist to make a long game interesting: on day one every resident is
## equally mediocre at everything, and by day thirty they are individuals — a
## good cook who feeds the household in half the time, a fit one who tires
## slowly, a specialist who earns noticeably more. None of that needs new code:
## a skill is a .tres, and the bonuses below are read by the systems that
## already exist.

## Practice needed for one level, in game minutes of doing the thing.
@export var minutes_per_level: float = 240.0
@export_range(1, 10) var max_level: int = 5

## Each level makes interactions that train this skill this much more effective.
## 0.12 means a level 5 cook restores 60% more hunger per meal.
@export_range(0.0, 1.0) var effect_bonus_per_level: float = 0.12

## Each level makes interactions that train this skill this much faster.
@export_range(0.0, 0.5) var speed_bonus_per_level: float = 0.06

## Each level raises wages by this fraction. Only useful on skills a job
## actually values (see JobData.skill_id).
@export_range(0.0, 0.5) var wage_bonus_per_level: float = 0.0

## Each level slows this need's decay by this fraction — fitness makes energy
## last longer, hygiene-related skills would make tidiness last, and so on.
## -1 means the skill has no passive effect on needs.
@export var slows_need: int = -1
@export_range(0.0, 0.3) var slows_need_per_level: float = 0.0

@export var icon_color: Color = Color(0.6, 0.8, 1.0)


## Total practice needed to reach `level` from nothing.
func xp_for_level(level: int) -> float:
	# Slightly super-linear: the fifth level should feel earned, not automatic.
	return minutes_per_level * float(level) * (1.0 + 0.2 * float(level - 1))


## Level implied by `xp` minutes of practice.
func level_for_xp(xp: float) -> int:
	var level := 0
	while level < max_level and xp >= xp_for_level(level + 1):
		level += 1
	return level


## 0..1 progress towards the next level, for the inspector bar.
func progress_to_next(xp: float) -> float:
	var level := level_for_xp(xp)
	if level >= max_level:
		return 1.0
	var floor_xp := xp_for_level(level)
	var next_xp := xp_for_level(level + 1)
	return clampf((xp - floor_xp) / maxf(next_xp - floor_xp, 1.0), 0.0, 1.0)
