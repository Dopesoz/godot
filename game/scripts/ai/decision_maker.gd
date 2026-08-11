class_name DecisionMaker
extends RefCounted

## Chooses what a citizen does next (design doc §15–§16).
##
## Phase 4 used "fix the lowest need". That falls apart the moment two needs are
## both low, or the fix is on the other side of the city: a citizen would walk
## past a fridge to reach a shower that is one point more urgent.
##
## So every option is scored instead, and the highest score wins:
##
##     score = Σ (gain × urgency × personality) / (duration + travel) × priority
##
## Each term is there for a reason:
##
##   gain        what the action actually restores, capped at what is missing —
##               eating when 95% full is worth almost nothing.
##   urgency     a curve, not a line. A need at 10 is far more than twice as
##               pressing as one at 20, which is what makes a citizen abandon
##               entertainment to go eat.
##   personality straight from the citizen's template, so a NEAT resident
##               genuinely prioritises washing rather than merely getting dirty
##               faster.
##   duration    per-minute value, so a ten minute snack competes fairly with a
##               forty minute cooked meal.
##   travel      walking is dead time, and it is counted in the same minutes as
##               the action itself.
##   schedule    the time of day, via ScheduleData. Not a command — a weight.
##               At 23:00 sleep is worth four times as much, so a citizen goes
##               to bed in the evening instead of when energy finally runs out.
##   duty        obligations, currently just the job: during the hours JobData
##               defines, working outranks almost everything; outside them it is
##               ignored. That is the whole of "going to work" — no separate
##               system, one more multiplier.
##   priority    the content author's thumb on the scale, from InteractionData.
##
## The whole thing is deliberately one readable formula rather than a behaviour
## tree: it is tuneable from data, and it explains itself (see `describe`).

## Options scoring below this are not worth getting up for. Set high enough that
## residents stop topping up a need that is merely a little low — without it
## they fidget between the fridge and the sofa all day.
const MIN_SCORE := 0.35

## An alternative must be this many times better before a citizen abandons what
## they are already doing. Without it they oscillate between two similar options.
const INTERRUPT_FACTOR := 2.0

## Value of one need point at its most urgent, used to keep scores in a sane
## numeric range.
const URGENCY_EXPONENT := 2.5

## Long actions are not punished in proportion to their length. Dividing by the
## full duration makes sleeping (eight hours) score an order of magnitude below
## a ten minute snack, so nobody would ever go to bed. Beyond this many minutes,
## extra duration stops counting against an action: what matters is the value it
## delivers and the walk to get there, not that resting takes a while.
const DURATION_CAP := 60.0


## Best option for this citizen, or an empty dictionary when nothing is worth
## doing. Shape: {furniture, interaction, path, score, reason}.
static func choose(citizen: Citizen, grid: WorldGrid, furniture: FurnitureRegistry) -> Dictionary:
	if grid == null or furniture == null:
		return {}
	var here := citizen.cell()
	var template := citizen.data()
	var walk_speed: float = template.walk_speed if template != null else 1.6
	var best := {}
	var best_score := MIN_SCORE

	# One candidate list per need the citizen actually wants raised. Needs that
	# are nearly full are skipped entirely, which keeps the search small.
	for need_type: int in citizen.needs:
		if citizen.need(need_type) >= GameConstants.NEED_MAX - 5.0:
			continue
		for option: Dictionary in furniture.find_for_need(need_type):
			var item: Furniture = option["furniture"]
			var interaction: InteractionData = option["interaction"]
			var access := item.access_cells(interaction, grid)
			if access.is_empty():
				continue

			var path: Array[Vector2i] = []
			var travel_minutes := 0.0
			if not access.has(here):
				# Sitting on a chair or lying in a bed means walking onto a cell
				# the object itself occupies.
				path = Pathfinder.find_path_to_any(grid, here, access, citizen.floor_index,
						interaction.stands_on_furniture)
				if path.is_empty():
					continue
				travel_minutes = float(path.size()) / maxf(walk_speed, 0.1)

			var score := score_option(citizen, interaction, travel_minutes)
			if score > best_score:
				best_score = score
				best = {
					"furniture": item,
					"interaction": interaction,
					"path": path,
					"score": score,
					"reason": describe(citizen, interaction),
				}
	return best


## Value per minute of doing this, from where the citizen is standing.
static func score_option(citizen: Citizen, interaction: InteractionData, travel_minutes: float) -> float:
	var template := citizen.data()
	var routine := citizen.schedule()
	var hour := GameClock.hour_of_day()
	var value := 0.0
	for need_type: int in interaction.need_effects:
		var effect := float(interaction.need_effects[need_type])
		if effect <= 0.0:
			# A cost, not a benefit (sleeping makes you hungry). Counted at face
			# value so an action that wrecks another need looks less attractive.
			value += effect * 0.5 * urgency(citizen.need(need_type))
			continue
		# No credit for filling a need past full.
		var gain := minf(effect, GameConstants.NEED_MAX - citizen.need(need_type))
		var importance := template.decay_multiplier(need_type) if template != null else 1.0
		if routine != null:
			importance *= routine.weight_for(need_type, hour)
		# Obligations (a job) weigh in through the same term as everything else.
		importance *= citizen.duty_weight(need_type)
		value += gain * urgency(citizen.need(need_type)) * importance
	if value <= 0.0:
		return 0.0
	var minutes := clampf(interaction.duration_minutes, 1.0, DURATION_CAP) + travel_minutes
	return value / minutes * maxf(interaction.priority, 0.01)


## How badly a need at `value` wants attention, 0..1 on a convex curve.
## Personality scales this later; the shape is what makes urgency non-linear.
static func urgency(value: float) -> float:
	var missing := clampf((GameConstants.NEED_MAX - value) / GameConstants.NEED_MAX, 0.0, 1.0)
	return pow(missing, URGENCY_EXPONENT)


## Should the citizen drop what they are doing for `candidate`?
static func should_interrupt(current_score: float, candidate_score: float) -> bool:
	return candidate_score > maxf(current_score, MIN_SCORE) * INTERRUPT_FACTOR


## Human-readable "why", shown in the inspector. The AI explaining itself is
## worth more than a slightly better AI that cannot.
static func describe(citizen: Citizen, interaction: InteractionData) -> String:
	var driving := -1
	var best := 0.0
	for need_type: int in interaction.need_effects:
		if float(interaction.need_effects[need_type]) <= 0.0:
			continue
		var weight := urgency(citizen.need(need_type))
		if weight > best:
			best = weight
			driving = need_type
	if driving == -1:
		return interaction.display_name
	var text := "%s (%s %d)" % [
		interaction.display_name,
		String(GameEnums.NeedType.keys()[driving]).to_lower(),
		roundi(citizen.need(driving)),
	]
	# When the routine is what tipped the choice, say so — otherwise "sleeping
	# at 23:00 with energy 60" looks like a bug rather than a bedtime.
	var routine := citizen.schedule()
	if routine != null and routine.weight_for(driving, GameClock.hour_of_day()) > 1.5:
		text += " · " + routine.label_at(GameClock.hour_of_day()).to_lower()
	return text
