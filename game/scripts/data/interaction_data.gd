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

## Optional gate: only citizens whose job matches may use it (e.g. a shop till).
@export var required_job_id: StringName = &""

## If true the citizen occupies the furniture's own cell (sitting on a chair);
## if false they stand on an adjacent free cell (using a stove).
@export var stands_on_furniture: bool = true


## Points per game minute for one need, so a partially finished action still
## pays out proportionally when it gets interrupted.
func rate_per_minute(need: GameEnums.NeedType) -> float:
	if duration_minutes <= 0.0:
		return 0.0
	return float(need_effects.get(need, 0.0)) / duration_minutes
