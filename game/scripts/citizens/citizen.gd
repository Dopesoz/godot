class_name Citizen
extends SimAgent

## A resident (design doc §12–§16). Pure model: it has no node, no sprite and no
## `_process`. The renderer reads `position` and draws something there; the
## SimScheduler decides how often this thinks.
##
## The state machine is deliberately small (§13: "a normal state machine suits
## this better"):
##
##   IDLE ──pick a goal──> WALKING ──arrive──> using state ──done──> IDLE
##                            └── no route ───────────────────────────┘
##
## Choosing *what* to do is not here: it lives in DecisionMaker, which scores
## every reachable option. This file only carries it out — walk there, do it,
## pay out the needs, and notice when something more urgent comes up.

## How far a need may fall before the citizen goes looking for a fix.
const SEEK_THRESHOLD := GameConstants.NEED_URGENT_THRESHOLD

var id: int = -1
var citizen_name: String = "Resident"
var data_id: StringName = &""

## Fractional cell position: the cell it stands in plus where inside it.
var position: Vector2 = Vector2.ZERO
var floor_index: int = 0

var state: int = GameEnums.CitizenState.IDLE
## NeedType -> 0..100.
var needs: Dictionary = {}

## Remaining cells to walk, nearest first.
var path: Array[Vector2i] = []
var target_furniture_id: int = -1
var target_interaction: InteractionData
var interaction_elapsed: float = 0.0

## Where this citizen lives, and with whom. Set when a household moves in; a
## resident with no home treats the whole city as fair game.
var home_room_id: int = -1
var home_building_id: int = -1
var household_id: int = -1

## What the citizen is doing and why, in words. Shown in the inspector: an AI
## that can explain itself is worth more than a slightly cleverer one that
## cannot.
var current_reason: String = ""
## Score of the current activity, kept so a candidate can be compared against it.
var current_score: float = 0.0

## Skill id -> minutes of practice. Levels are derived from this, so a save
## carries one number per skill and the curve stays a content decision.
var skills: Dictionary = {}

## Interaction id -> 0..1 staleness. Rises while doing something, fades while
## not. This is the difference between a resident who watches television all
## evening and one who watches some television, then picks up the guitar.
var boredom: Dictionary = {}

## Money earned today, shown in the inspector so the player can see a job
## actually paying rather than just a number moving in the corner.
var earned_today: int = 0

var _data: CitizenData
var _schedule: ScheduleData
var _job: JobData
var _grid: WorldGrid
var _furniture: FurnitureRegistry
## Re-picking a goal every single tick would thrash; wait this many game minutes
## after a failure before trying again.
var _retry_in: float = 0.0
## Countdown to the next "is there something better to do?" check.
var _recheck_in: float = GameConstants.AI_RECHECK_MINUTES
## Sub-unit wages carried between ticks so nothing is lost to rounding.
var _wage_fraction: float = 0.0


func setup(grid: WorldGrid, furniture: FurnitureRegistry, template: CitizenData) -> void:
	_grid = grid
	_furniture = furniture
	_data = template
	if needs.is_empty() and template != null:
		for need: int in GameEnums.NeedType.values():
			needs[need] = template.starting_need(need)
	if skills.is_empty() and template != null:
		for skill_id: StringName in template.starting_skills:
			skills[skill_id] = float(template.starting_skills[skill_id])


func data() -> CitizenData:
	if _data == null and data_id != &"":
		_data = Database.get_citizen(data_id)
	return _data


# --- Skills -----------------------------------------------------------------

func skill_xp(skill_id: StringName) -> float:
	return float(skills.get(skill_id, 0.0))


func skill_level(skill_id: StringName) -> int:
	if skill_id == &"":
		return 0
	var skill := Database.get_skill(skill_id)
	return skill.level_for_xp(skill_xp(skill_id)) if skill != null else 0


## Practice. Levelling up is announced, because watching a resident get visibly
## better at something is half the reason skills exist.
func train(skill_id: StringName, minutes: float) -> void:
	if skill_id == &"" or minutes <= 0.0:
		return
	var skill := Database.get_skill(skill_id)
	if skill == null:
		return
	var before := skill.level_for_xp(skill_xp(skill_id))
	skills[skill_id] = skill_xp(skill_id) + minutes
	var after := skill.level_for_xp(skill_xp(skill_id))
	if after > before:
		EventBus.notify("%s reached %s level %d" % [citizen_name, skill.display_name, after])


## How much better this citizen is at an action than a beginner: 1.0 for no
## skill, 1.6 for a level 5 cook cooking.
func skill_effect_multiplier(interaction: InteractionData) -> float:
	if interaction == null or interaction.skill_id == &"":
		return 1.0
	var skill := Database.get_skill(interaction.skill_id)
	if skill == null:
		return 1.0
	return 1.0 + skill.effect_bonus_per_level * float(skill_level(interaction.skill_id))


## Practised actions also take less time.
func skill_speed_multiplier(interaction: InteractionData) -> float:
	if interaction == null or interaction.skill_id == &"":
		return 1.0
	var skill := Database.get_skill(interaction.skill_id)
	if skill == null:
		return 1.0
	return maxf(1.0 - skill.speed_bonus_per_level * float(skill_level(interaction.skill_id)), 0.4)


func can_perform(interaction: InteractionData) -> bool:
	if interaction == null:
		return false
	if interaction.required_skill_level <= 0:
		return true
	return skill_level(interaction.skill_id) >= interaction.required_skill_level


## Somebody else's home is not yours to sleep in. Public and commercial places
## are open to everyone, and a resident with no home of their own is not fussy —
## but once families live in separate houses, this one rule is what stops the
## neighbours wandering in and using the nearest bed.
func may_use(item: Furniture) -> bool:
	if item == null:
		return false
	if item.building_id == -1 or home_building_id == -1:
		return true
	if item.building_id == home_building_id:
		return true
	var lots := _lots()
	var building := lots.get_building(item.building_id) if lots != null else null
	return building == null or not building.is_residential()


## Everyone else currently using the same object.
func companions() -> Array[int]:
	var result: Array[int] = []
	var item := _target()
	if item == null:
		return result
	for user_id: int in item.users:
		if user_id != id:
			result.append(user_id)
	return result


## Time spent together moves a relationship, faster for the charismatic and
## faster still between people who already get on — which is why friendships
## accelerate and strangers take a while.
func _socialise(minutes: float) -> void:
	if target_interaction == null or target_interaction.social_weight <= 0.0:
		return
	var book := _relationships()
	if book == null:
		return
	var charm := 1.0 + 0.15 * float(skill_level(&"charisma"))
	for other_id in companions():
		var current := book.get_value(id, other_id)
		# Warmth grows with the time spent and with how well it is already going;
		# a bad relationship barely improves by sitting in the same room.
		var rapport := 1.0 + clampf(current, -60.0, 60.0) / 120.0
		book.adjust(id, other_id,
				minutes * GameConstants.RELATIONSHIP_PER_MINUTE
				* target_interaction.social_weight * charm * rapport)


func _relationships() -> RelationshipRegistry:
	if _furniture == null:
		return null
	return _furniture.get_parent().get_node_or_null("Relationships") as RelationshipRegistry


## How much better company makes this action. Solitary actions ignore it; a
## conversation with a friend is worth far more than one with a stranger.
func company_multiplier(interaction: InteractionData, item: Furniture) -> float:
	if interaction == null or item == null or interaction.social_weight <= 0.0:
		return 1.0
	var book := _relationships()
	var present := 0
	var warmth := 0.0
	for user_id: int in item.users:
		if user_id == id:
			continue
		present += 1
		if book != null:
			warmth += book.get_value(id, user_id) / 100.0
	if present == 0:
		# Nobody there yet. Worth much less than joining someone, but not
		# worthless — somebody has to sit down first, or two lonely residents
		# would wait for each other forever.
		return 1.0 - 0.6 * interaction.social_weight
	var bonus := 0.7 * float(present) + 0.6 * warmth
	return 1.0 + interaction.social_weight * bonus


func _lots() -> BuildingLots:
	if _furniture == null:
		return null
	return _furniture.get_parent().get_node_or_null("Lots") as BuildingLots


# --- Taste and variety ------------------------------------------------------

## How much this particular person likes this particular action.
func affinity(interaction: InteractionData) -> float:
	var template := data()
	if template == null or interaction == null:
		return 1.0
	return float(template.interaction_affinity.get(interaction.id, 1.0))


## Falls towards BOREDOM_FLOOR the more recently and more often the citizen has
## done this, and climbs back as they do other things.
func variety_multiplier(interaction: InteractionData) -> float:
	if interaction == null:
		return 1.0
	var stale := float(boredom.get(interaction.id, 0.0))
	return lerpf(1.0, GameConstants.BOREDOM_FLOOR, clampf(stale, 0.0, 1.0))


func _age_boredom(minutes: float) -> void:
	if boredom.is_empty():
		return
	var recovery := minutes / GameConstants.BOREDOM_RECOVERY_MINUTES
	for key: StringName in boredom.keys():
		var value: float = float(boredom[key]) - recovery
		if value <= 0.001:
			boredom.erase(key)
		else:
			boredom[key] = value


## The citizen's profession, or null when unemployed.
func job() -> JobData:
	if _job == null:
		var template := data()
		if template != null and template.job_id != &"":
			_job = Database.get_job(template.job_id)
	return _job


func is_on_shift() -> bool:
	var profession := job()
	if profession == null:
		return false
	return profession.is_working_day(GameClock.day_of_week()) and profession.is_working_hour(GameClock.hour_of_day())


## Extra weight the citizen's obligations put on a need right now. Only work has
## one: it is made pressing during the hours JobData defines and almost ignored
## outside them, which is what turns "a need called WORK" into "a job".
func duty_weight(need_type: int) -> float:
	if need_type != GameEnums.NeedType.WORK:
		return 1.0
	if job() == null:
		return 0.0
	return GameConstants.WORK_DUTY_WEIGHT_ON_SHIFT if is_on_shift() else GameConstants.WORK_DUTY_WEIGHT_OFF_SHIFT


## Called at the start of each day: today's shift is owed again, or not, if this
## is a day off.
func start_new_day() -> void:
	earned_today = 0
	var profession := job()
	var owes_work := profession != null and profession.is_working_day(GameClock.day_of_week())
	needs[GameEnums.NeedType.WORK] = 0.0 if owes_work else GameConstants.NEED_MAX


## Wage for one minute on the job, derived from the daily salary and the length
## of the shift, so pay and hours stay in one place (JobData).
func wage_per_minute() -> float:
	var profession := job()
	if profession == null:
		return 0.0
	var hours := profession.end_hour - profession.start_hour
	if hours <= 0.0:
		hours += 24.0
	var base := float(profession.salary_per_day) / maxf(hours * 60.0, 1.0)
	# An employer pays for the skill it named, so getting better is felt in the
	# balance as well as in the action.
	var skill := Database.get_skill(profession.skill_id) if profession.skill_id != &"" else null
	if skill != null:
		base *= 1.0 + skill.wage_bonus_per_level * float(skill_level(profession.skill_id))
	return base


## The citizen's daily routine, or null when they live purely by their needs.
func schedule() -> ScheduleData:
	if _schedule == null:
		var template := data()
		if template != null and template.schedule_id != &"":
			_schedule = Database.get_schedule(template.schedule_id)
	return _schedule


## What the routine says this hour is for ("Evening", "Night"), for the panel.
func schedule_label() -> String:
	var routine := schedule()
	return routine.label_at(GameClock.hour_of_day()) if routine != null else ""


func cell() -> Vector2i:
	return Vector2i(roundi(position.x), roundi(position.y))


func get_sim_cell() -> Vector2i:
	return cell()


## Takes a plain int rather than the enum type: need values arrive from
## dictionaries and JSON, neither of which narrows back into an enum.
func need(type: int) -> float:
	return float(needs.get(type, 100.0))


func lowest_need() -> int:
	var worst: int = GameEnums.NeedType.HUNGER
	var worst_value := 1000.0
	for type: int in needs:
		var value: float = needs[type]
		if value < worst_value:
			worst_value = value
			worst = type
	return worst


func state_name() -> String:
	return Loc.t(String(GameEnums.CitizenState.keys()[state]).capitalize().replace("_", " "))


# --- Simulation -------------------------------------------------------------

func sim_tick(minutes: float, lod: GameEnums.SimLOD) -> void:
	_decay_needs(minutes)
	_age_boredom(minutes)
	_retry_in = maxf(_retry_in - minutes, 0.0)

	match state:
		GameEnums.CitizenState.IDLE:
			_tick_idle()
		GameEnums.CitizenState.WALKING:
			_tick_walking(minutes, lod)
		_:
			_tick_interaction(minutes)


## Needs fall continuously, scaled by personality. Because the tick carries the
## elapsed game minutes rather than a fixed step, a citizen simulated once per
## hour ends up exactly as hungry as one simulated ten times a second.
func _decay_needs(minutes: float) -> void:
	var template := data()
	var scale: float = GameConstants.STATE_DECAY_SCALE.get(state, 1.0)
	for type: int in needs:
		var per_hour: float = GameConstants.NEED_DECAY_PER_HOUR.get(type, 0.0) * scale
		if template != null:
			per_hour *= template.decay_multiplier(type)
		per_hour *= _skill_decay_multiplier(type)
		per_hour *= CityEvents.decay_multiplier(type)
		var before: float = needs[type]
		var after := clampf(before - per_hour * minutes / 60.0, GameConstants.NEED_MIN, GameConstants.NEED_MAX)
		needs[type] = after
		if before > SEEK_THRESHOLD and after <= SEEK_THRESHOLD:
			EventBus.citizen_need_critical.emit(id, type, after)


## Skills that slow a need down (fitness on energy) apply here, so training
## shows up as a permanent, felt improvement rather than a number in a panel.
func _skill_decay_multiplier(need_type: int) -> float:
	var multiplier := 1.0
	for skill_id: StringName in skills:
		var skill := Database.get_skill(skill_id)
		if skill == null or skill.slows_need != need_type:
			continue
		multiplier *= maxf(1.0 - skill.slows_need_per_level * float(skill_level(skill_id)), 0.3)
	return multiplier


## How far a resident will wander when they have nothing to do, and how much
## searching that walk is allowed to cost.
const STROLL_RADIUS := 9
const STROLL_NODE_BUDGET := 700


func _tick_idle() -> void:
	if _retry_in > 0.0:
		return
	var goal := _choose_goal()
	if goal.is_empty():
		# Nothing worth getting up for. Take a short stroll instead of freezing
		# in place, then reconsider — an idle house still looks alive.
		_retry_in = 20.0
		_begin_wander()
		return
	_begin_walk(goal)


func _choose_goal() -> Dictionary:
	return DecisionMaker.choose(self, _grid, _furniture)


## Nothing worth doing right now — so go somewhere rather than shuffle on the
## spot.
##
## The old version stepped to a random neighbouring cell, which is what "idle"
## looked like: a person twitching in a doorway. A resident with nowhere to be
## still has somewhere to go — out to the street, through the park, back home —
## and walking a real route there reads as a person with a reason, costs one
## path, and has the side effect of taking them past other people.
func _begin_wander() -> void:
	if _grid == null:
		return
	var here := cell()
	var destination := _stroll_destination(here)
	if destination != here:
		# A short budget on purpose: a walk that needs a long search is not a
		# walk worth taking, and the fallback below is free.
		var route := Pathfinder.find_path(_grid, here, destination, floor_index, false,
				STROLL_NODE_BUDGET)
		if not route.is_empty():
			path = route
			target_furniture_id = -1
			target_interaction = null
			current_reason = "REASON_WALK"
			current_score = 0.0
			_set_state(GameEnums.CitizenState.WALKING)
			return
	_step_aside(here)


## Somewhere plausible to head for: the pavement and the road are what a town is
## walked on, so cells with a floor are preferred over open grass, and home is
## always a candidate for someone who is out.
func _stroll_destination(here: Vector2i) -> Vector2i:
	var best := here
	var best_score := -1.0
	for attempt in 10:
		var offset := Vector2i(randi_range(-STROLL_RADIUS, STROLL_RADIUS),
				randi_range(-STROLL_RADIUS, STROLL_RADIUS))
		var candidate := here + offset
		if not _grid.in_bounds(candidate) or not _grid.is_walkable(candidate, floor_index):
			continue
		var data := _grid.get_cell(candidate, floor_index)
		# Only somewhere built: a pavement, a road, a room. Open grass is not a
		# destination, it is the space between them — and refusing it also keeps
		# a resident in the middle of a field from searching half the map.
		if data == null or data.floor_id == &"":
			continue
		var score := float(IsoUtils.cell_distance(here, candidate))
		if home_building_id != -1 and data.building_id == home_building_id:
			score *= 1.5
		if score > best_score:
			best_score = score
			best = candidate
	return best


## The fallback when there is nowhere to walk to: one step, so a crowded room
## still shifts about instead of freezing.
func _step_aside(here: Vector2i) -> void:
	var candidates: Array[Vector2i] = []
	for offset in IsoUtils.neighbors(here):
		if _grid.can_walk_between(here, offset, floor_index):
			candidates.append(offset)
	if candidates.is_empty():
		return
	var destination: Vector2i = candidates[randi() % candidates.size()]
	var route: Array[Vector2i] = [destination]
	path = route
	target_furniture_id = -1
	target_interaction = null
	current_reason = "REASON_WALK"
	current_score = 0.0
	_set_state(GameEnums.CitizenState.WALKING)


func _begin_walk(goal: Dictionary) -> void:
	var item: Furniture = goal["furniture"]
	var interaction: InteractionData = goal["interaction"]
	# Claim the object before walking, so two citizens never head for one bed.
	if not item.is_free_for(interaction):
		_retry_in = 10.0
		return
	item.users.append(id)
	target_furniture_id = item.id
	target_interaction = interaction
	current_reason = String(goal.get("reason", interaction.display_name))
	current_score = float(goal.get("score", 0.0))
	var route: Array[Vector2i] = goal["path"]
	path = route
	if path.is_empty():
		_start_interaction()
	else:
		_set_state(GameEnums.CitizenState.WALKING)


func _tick_walking(minutes: float, lod: GameEnums.SimLOD) -> void:
	if path.is_empty():
		_start_interaction()
		return
	# Far from the camera nobody can see the walk, so it is resolved instantly
	# and the citizen keeps its schedule without costing anything.
	if lod == GameEnums.SimLOD.ABSTRACT:
		position = Vector2(path[path.size() - 1])
		path.clear()
		_start_interaction()
		return

	var template := data()
	var speed := template.walk_speed if template != null else 1.6
	var budget := speed * minutes
	while budget > 0.0 and not path.is_empty():
		var next := Vector2(path[0])
		var step := next - position
		var distance := step.length()
		if distance <= budget:
			position = next
			path.remove_at(0)
			budget -= distance
		else:
			position += step / distance * budget
			budget = 0.0
	if path.is_empty():
		_start_interaction()


func _start_interaction() -> void:
	var item := _target()
	if item == null or target_interaction == null:
		# Arriving from a wander: nothing to do here, and nothing went wrong.
		if target_furniture_id == -1 and target_interaction == null:
			current_reason = ""
			_set_state(GameEnums.CitizenState.IDLE)
			return
		_abort_goal()
		return
	interaction_elapsed = 0.0
	_set_state(target_interaction.state)
	EventBus.citizen_interaction_started.emit(id, item.id, target_interaction.display_name)


## Needs are paid out continuously rather than in a lump at the end, so an
## interrupted meal still fed the citizen for as long as it lasted.
func _tick_interaction(minutes: float) -> void:
	if target_interaction == null:
		_abort_goal()
		return
	interaction_elapsed += minutes
	train(target_interaction.skill_id, minutes * target_interaction.xp_rate)
	boredom[target_interaction.id] = minf(
			float(boredom.get(target_interaction.id, 0.0)) + minutes / GameConstants.BOREDOM_MINUTES, 1.0)
	_socialise(minutes)
	if state == GameEnums.CitizenState.WORKING:
		_earn_wages(minutes)
	_check_for_interruption(minutes)
	if target_interaction == null:
		return
	var effectiveness := skill_effect_multiplier(target_interaction)
	var company := company_multiplier(target_interaction, _target())
	for type: int in target_interaction.need_effects:
		var gain := target_interaction.rate_per_minute(type) * minutes
		# Skill improves what the action gives, never what it costs.
		if gain > 0.0:
			gain *= effectiveness
			if type == GameEnums.NeedType.SOCIAL:
				gain *= company
			# A coffee stops helping once you are reasonably awake.
			gain = minf(gain, target_interaction.headroom(type, need(type)))
		needs[type] = clampf(need(type) + gain, GameConstants.NEED_MIN, GameConstants.NEED_MAX)
	if interaction_elapsed >= target_interaction.duration_minutes * skill_speed_multiplier(target_interaction):
		_finish_interaction()


## Paid by the minute worked rather than in a lump at the end of the shift, so
## an interrupted day still pays for the hours actually put in.
func _earn_wages(minutes: float) -> void:
	if not is_on_shift():
		return
	_wage_fraction += wage_per_minute() * minutes
	var whole := int(_wage_fraction)
	if whole <= 0:
		return
	_wage_fraction -= float(whole)
	earned_today += whole
	Economy.earn(whole, "wages")


## Something urgent can come up mid-activity — that is the difference between a
## schedule and a simulation. Re-scoring is not free, so it happens on a timer
## rather than every tick, and only a clearly better option wins (DecisionMaker
## holds the hysteresis).
func _check_for_interruption(minutes: float) -> void:
	_recheck_in -= minutes
	if _recheck_in > 0.0:
		return
	_recheck_in = GameConstants.AI_RECHECK_MINUTES
	var candidate := _choose_goal()
	if candidate.is_empty():
		return
	var resistance := target_interaction.interrupt_resistance
	if not DecisionMaker.should_interrupt(current_score * resistance, float(candidate.get("score", 0.0))):
		return
	var item := _target()
	if item != null:
		item.users.erase(id)
		EventBus.citizen_interaction_finished.emit(id, item.id, target_interaction.display_name)
	target_furniture_id = -1
	target_interaction = null
	interaction_elapsed = 0.0
	_begin_walk(candidate)


func _finish_interaction() -> void:
	# Short actions accumulate almost no staleness by duration alone, so each
	# completed use counts as well. This is what stops the coffee loop.
	if target_interaction != null:
		boredom[target_interaction.id] = minf(
				float(boredom.get(target_interaction.id, 0.0)) + GameConstants.BOREDOM_PER_USE, 1.0)
	var item := _target()
	if item != null:
		item.users.erase(id)
		if target_interaction.payout_per_skill_level != 0:
			# Selling what you made: worth more the better you are at it.
			var payout := target_interaction.payout_per_skill_level * maxi(skill_level(target_interaction.skill_id), 1)
			earned_today += payout
			Economy.earn(payout, "sales")
		if target_interaction.money_delta != 0:
			if target_interaction.money_delta > 0:
				Economy.earn(target_interaction.money_delta, "wages")
			else:
				Economy.try_spend(-target_interaction.money_delta, "spending")
		EventBus.citizen_interaction_finished.emit(id, item.id, target_interaction.display_name)
	target_furniture_id = -1
	target_interaction = null
	interaction_elapsed = 0.0
	current_reason = ""
	current_score = 0.0
	_set_state(GameEnums.CitizenState.IDLE)


## Something the citizen was heading for stopped existing — a bed sold, a wall
## built across the route. Release the claim and think again in a moment.
func _abort_goal() -> void:
	var item := _target()
	if item != null:
		item.users.erase(id)
	target_furniture_id = -1
	target_interaction = null
	path.clear()
	_retry_in = 10.0
	_set_state(GameEnums.CitizenState.IDLE)


func _target() -> Furniture:
	if _furniture == null or target_furniture_id == -1:
		return null
	return _furniture.items.get(target_furniture_id)


func _set_state(new_state: int) -> void:
	if state == new_state:
		return
	state = new_state
	EventBus.citizen_state_changed.emit(id, state)


# --- Persistence ------------------------------------------------------------
# The citizen's own state is saved; what it happened to be walking towards is
# not. On load everyone stands still for a moment and then picks a new goal,
# which is both simpler and more robust than restoring a stale route.

func save_data() -> Dictionary:
	var stored_needs := {}
	for type: int in needs:
		stored_needs[str(type)] = needs[type]
	return {
		"id": id,
		"name": citizen_name,
		"data_id": String(data_id),
		"x": position.x,
		"y": position.y,
		"floor": floor_index,
		"home_room": home_room_id,
		"home_building": home_building_id,
		"household": household_id,
		"earned_today": earned_today,
		"skills": skills.duplicate(),
		"needs": stored_needs,
	}


static func from_save(entry: Dictionary) -> Citizen:
	var citizen := Citizen.new()
	citizen.id = int(entry.get("id", -1))
	citizen.citizen_name = String(entry.get("name", "Resident"))
	citizen.data_id = StringName(entry.get("data_id", ""))
	citizen.position = Vector2(float(entry.get("x", 0.0)), float(entry.get("y", 0.0)))
	citizen.floor_index = int(entry.get("floor", 0))
	citizen.home_room_id = int(entry.get("home_room", -1))
	citizen.home_building_id = int(entry.get("home_building", -1))
	citizen.household_id = int(entry.get("household", -1))
	citizen.earned_today = int(entry.get("earned_today", 0))
	var stored_skills: Dictionary = entry.get("skills", {})
	for key: String in stored_skills.keys():
		citizen.skills[StringName(key)] = float(stored_skills[key])
	var stored: Dictionary = entry.get("needs", {})
	for key: String in stored.keys():
		citizen.needs[int(key)] = float(stored[key])
	return citizen
