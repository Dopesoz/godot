class_name InteractionData
extends GameData

## One thing a citizen can do with a piece of furniture (design doc §16).
##
## A bed owns a "Sleep" interaction, a fridge owns "Get Food", a computer owns
## both "Work" and "Play". The AI never hardcodes furniture names: it asks the
## world for every reachable interaction that raises the need it cares about,
## scores them, and picks one.

## State the citizen enters while performing this. See GameEnums.CitizenState.
@export var state: GameEnums.CitizenState = GameEnums.CitizenState.IDLE

## How long the action takes, in game minutes.
@export var duration_minutes: float = 30.0

## Need -> points restored over the full duration. Negative values drain.
## Keys are GameEnums.NeedType values.
@export var need_effects: Dictionary = {}

## Money earned (positive) or spent (negative) when the action completes.
@export var money_delta: int = 0

## How many citizens can use this at once. A bed is 1, a sofa may be 3.
@export var capacity: int = 1

## Interactions with a higher priority win ties when several fix the same need.
@export var priority: float = 1.0

## Skill this action trains and is improved by (SkillData id). Empty means the
## action is the same whoever does it.
@export var skill_id: StringName = &""

## Minutes of skill practice earned per minute spent. Above 1.0 for focused
## practice (an instrument), below for incidental practice (cooking dinner).
@export var xp_rate: float = 1.0

## Locked until the citizen reaches this level in `skill_id`. This is what makes
## a long game open up: new things become possible rather than merely faster.
@export_range(0, 10) var required_skill_level: int = 0

## Need -> the highest value this action can raise it to. Coffee cannot replace
## sleep, and a snack cannot replace dinner: without a ceiling, cheap fast fixes
## dominate the scoring forever and the citizen never does anything else. Needs
## not listed have no ceiling.
@export var effect_ceilings: Dictionary = {}

## Money earned when the action completes, scaled by skill level. A painting
## sells for more when a better painter made it.
@export var payout_per_skill_level: int = 0

## Optional gate: only citizens whose job matches may use it (e.g. a shop till).
@export var required_job_id: StringName = &""

## If true the citizen occupies the furniture's own cell (sitting on a chair);
## if false they stand on an adjacent free cell (using a stove).
@export var stands_on_furniture: bool = true


## Points per game minute for one need, so a partially finished action still
## pays out proportionally when it gets interrupted.
## The most this action can still give a citizen currently at `current`.
func headroom(need: int, current: float) -> float:
	var ceiling: float = float(effect_ceilings.get(need, GameConstants.NEED_MAX))
	return maxf(ceiling - current, 0.0)


func rate_per_minute(need: int) -> float:
	if duration_minutes <= 0.0:
		return 0.0
	return float(need_effects.get(need, 0.0)) / duration_minutes
