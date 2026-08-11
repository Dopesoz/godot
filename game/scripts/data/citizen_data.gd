class_name CitizenData
extends GameData

## Template for a resident (design doc §5). This is the archetype the generator
## starts from — the living citizen keeps its own mutable needs, position and
## relationships in the model layer, not here.

enum Gender { FEMALE, MALE, OTHER }

## Personality shifts how fast needs decay and how actions are scored, so two
## citizens in the same house behave differently.
enum Personality {
	BALANCED,
	NEAT,      ## Hygiene decays fast, cleaning is rewarding.
	LAZY,      ## Energy decays fast, prefers sitting.
	SOCIAL,    ## Social decays fast, seeks other citizens.
	WORKAHOLIC ## Tolerates low needs while working.
}

@export var gender: Gender = Gender.OTHER
@export_range(0, 120) var age: int = 30
@export var personality: Personality = Personality.BALANCED

## Starting profession. Empty means unemployed.
@export var job_id: StringName = &""

## Daily routine (ScheduleData id). Empty means "driven purely by needs", which
## is how citizens behaved before Phase 6.
@export var schedule_id: StringName = &"schedule_default"

## Starting need values, 0..100. Missing keys default to 80.
## Keys are GameEnums.NeedType values.
@export var initial_needs: Dictionary = {}

## Per-need multiplier on the global decay rate, from personality or age.
## Keys are GameEnums.NeedType values, values are floats around 1.0.
@export var need_decay_multipliers: Dictionary = {}

## Cells per second when walking at FULL simulation LOD.
@export var walk_speed: float = 1.6

## Name pools used by the random citizen generator when this template is used
## as an archetype rather than a specific person.
@export var first_names: PackedStringArray = PackedStringArray()
@export var last_names: PackedStringArray = PackedStringArray()


func starting_need(need: int) -> float:
	return clampf(float(initial_needs.get(need, 80.0)), GameConstants.NEED_MIN, GameConstants.NEED_MAX)


func decay_multiplier(need: int) -> float:
	return float(need_decay_multipliers.get(need, 1.0))
