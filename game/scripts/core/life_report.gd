class_name LifeReport
extends RefCounted

## Simulates several days and reports how the residents actually spent them.
##
##     godot --headless --fixed-fps 60 --path game -- --demo --report 7
##
## Balance is the last thing in this project still described as "rough", and
## rough is what an opinion sounds like. This turns it into numbers: where the
## hours went, how many different things anyone did, how low needs got, and
## whether the money moved. Those are the questions the design doc actually
## asks — §34 wants a house worth watching, and the brief asks for real choice
## between work, fun and getting better at something. Both are measurable.
##
## It measures; it does not judge. Nothing here changes the simulation, and the
## clock is driven by the ordinary game loop at the fastest speed, so what is
## reported is what a player would have watched.

## Sampled every game minute: what each resident was doing, in minutes.
static var _state_minutes: Dictionary = {}
## Every distinct interaction anyone finished, and how often.
static var _actions: Dictionary = {}
## Distinct actions per resident, so "the city is varied" cannot hide the fact
## that each individual did the same two things.
static var _actions_per_citizen: Dictionary = {}
## The lowest each need ever fell, and how often one went critical.
static var _need_low: Dictionary = {}
static var _criticals: Dictionary = {}
static var _minutes: int = 0
## Idle is the number that matters most — it is the shape of a boring game — so
## it is broken down by what the resident said they were doing and by the hour
## of the day. "Idle at 3am" is sleep balance; "idle at noon" is a dead city.
static var _idle_reasons: Dictionary = {}
static var _idle_by_hour: Array = []


static func maybe_run(world: Node) -> void:
	var args := OS.get_cmdline_user_args()
	var index := args.find("--report")
	if index == -1:
		return
	var days := int(args[index + 1]) if index + 1 < args.size() else 3
	await _run(world, days)


static func _run(world: Node, days: int) -> void:
	var citizens := world.get_node_or_null("Citizens") as CitizenRegistry
	var relations := world.get_node_or_null("Relationships") as RelationshipRegistry
	if citizens == null:
		return
	_reset()

	EventBus.minute_passed.connect(_on_minute.bind(citizens))
	EventBus.citizen_interaction_finished.connect(_on_interaction)
	EventBus.citizen_need_critical.connect(_on_critical)

	var money_before := Economy.money
	var skills_before := _skill_total(citizens)
	GameClock.set_speed_index(GameConstants.TIME_SPEEDS.size() - 1)
	var until := GameClock.day + days
	# Driven by the ordinary loop rather than by calling advance() in a tight
	# loop: the scheduler hands out ticks per frame, and skipping frames would
	# report a simulation nobody will ever run.
	while GameClock.day < until:
		await world.get_tree().process_frame

	_print(citizens, relations, days, Economy.money - money_before,
			_skill_total(citizens) - skills_before)
	world.get_tree().quit()


static func _reset() -> void:
	_state_minutes.clear()
	_actions.clear()
	_actions_per_citizen.clear()
	_need_low.clear()
	_criticals.clear()
	_idle_reasons.clear()
	_idle_by_hour = []
	for i in 24:
		_idle_by_hour.append(0)
	_minutes = 0


static func _on_minute(hour: int, _minute: int, citizens: CitizenRegistry) -> void:
	_minutes += 1
	for citizen: Citizen in citizens.all():
		var key: int = citizen.state
		_state_minutes[key] = int(_state_minutes.get(key, 0)) + 1
		if key == GameEnums.CitizenState.IDLE:
			var reason := citizen.current_reason if citizen.current_reason != "" else "(nothing chosen)"
			_idle_reasons[reason] = int(_idle_reasons.get(reason, 0)) + 1
			_idle_by_hour[hour] = int(_idle_by_hour[hour]) + 1
		for need: int in citizen.needs:
			var value := float(citizen.needs[need])
			_need_low[need] = minf(float(_need_low.get(need, 100.0)), value)


static func _on_interaction(citizen_id: int, _furniture_id: int, action: String) -> void:
	_actions[action] = int(_actions.get(action, 0)) + 1
	if not _actions_per_citizen.has(citizen_id):
		_actions_per_citizen[citizen_id] = {}
	var own: Dictionary = _actions_per_citizen[citizen_id]
	own[action] = int(own.get(action, 0)) + 1


static func _on_critical(_citizen_id: int, need: int, _value: float) -> void:
	_criticals[need] = int(_criticals.get(need, 0)) + 1


static func _skill_total(citizens: CitizenRegistry) -> float:
	var total := 0.0
	for citizen: Citizen in citizens.all():
		for id: StringName in citizen.skills:
			total += float(citizen.skills[id])
	return total


static func _print(citizens: CitizenRegistry, relations: RelationshipRegistry, days: int,
		money_delta: int, skill_delta: float) -> void:
	var population := maxi(citizens.count(), 1)
	print("\n=== %d days, %d residents ===" % [days, population])

	print("\nWhere the hours went")
	var total_samples := maxi(_minutes * population, 1)
	var states: Array = _state_minutes.keys()
	states.sort_custom(func(a: int, b: int) -> bool:
		return int(_state_minutes[a]) > int(_state_minutes[b]))
	for state: int in states:
		var share := float(_state_minutes[state]) / float(total_samples) * 100.0
		print("  %-14s %5.1f%%  %s" % [
			GameEnums.CitizenState.keys()[state].to_lower(),
			share,
			"#".repeat(roundi(share / 2.0)),
		])

	if not _idle_reasons.is_empty():
		print("\nIdle, by what they last decided")
		var reasons: Array = _idle_reasons.keys()
		reasons.sort_custom(func(a: String, b: String) -> bool:
			return int(_idle_reasons[a]) > int(_idle_reasons[b]))
		for reason: String in reasons.slice(0, 8):
			print("  %-28s %5.1f%% of all idle" % [reason,
					float(_idle_reasons[reason]) / float(maxi(_total(_idle_reasons), 1)) * 100.0])
		var busiest := 0
		for hour in 24:
			busiest = maxi(busiest, int(_idle_by_hour[hour]))
		print("\nIdle by hour (00 -> 23)")
		var bars := ""
		for hour in 24:
			var height := roundi(float(_idle_by_hour[hour]) / float(maxi(busiest, 1)) * 8.0)
			bars += " ▁▂▃▄▅▆▇█"[height]
		print("  " + bars)

	print("\nWhat they did  (%d different things, %d times)" % [_actions.size(), _total(_actions)])
	var actions: Array = _actions.keys()
	actions.sort_custom(func(a: String, b: String) -> bool:
		return int(_actions[a]) > int(_actions[b]))
	for action: String in actions:
		print("  %-18s %4d" % [action, int(_actions[action])])

	print("\nVariety per resident  (distinct activities each)")
	var lonely := 0
	for citizen: Citizen in citizens.all():
		var own: Dictionary = _actions_per_citizen.get(citizen.id, {})
		if own.size() <= 2:
			lonely += 1
		print("  %-16s %2d  %s" % [citizen.citizen_name, own.size(),
				", ".join(own.keys())])
	if lonely > 0:
		print("  -> %d resident(s) did two things or fewer all week" % lonely)

	print("\nNeeds  (lowest reached, and how often critical)")
	for need: int in GameEnums.NeedType.values():
		print("  %-14s low %5.1f   critical %d" % [
			GameEnums.NeedType.keys()[need].to_lower(),
			float(_need_low.get(need, 100.0)),
			int(_criticals.get(need, 0)),
		])

	var friendships := 0
	if relations != null:
		for value: float in relations.values.values():
			if value >= RelationshipRegistry.FRIEND_THRESHOLD:
				friendships += 1
	print("\nMoney  %s%d over %d days (%s%d/day)   skills gained %.1f   friendships %d" % [
		"+" if money_delta >= 0 else "", money_delta, days,
		"+" if money_delta >= 0 else "", roundi(float(money_delta) / float(days)),
		skill_delta, friendships,
	])


static func _total(counts: Dictionary) -> int:
	var sum := 0
	for value: int in counts.values():
		sum += value
	return sum
