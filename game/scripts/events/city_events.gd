extends Node

## Autoload: CityEvents
##
## Runs the city's events (design doc §11). It is a service rather than a node
## in the world scene for the same reason the clock is: an event is city-wide
## state that has to survive a scene change and be readable from the model layer
## without anybody holding a reference to a scene.
##
## What an event does is deliberately narrow: it multiplies need weights and
## decay rates for as long as it runs. Everything visible — residents gathering
## for a festival, washing more often in a heatwave — is the existing decision
## formula reacting to different numbers. No event-specific behaviour exists, so
## a new event is a .tres file.

## Active events: id -> {"data": EventData, "ends_at": float total game minutes}
var active: Dictionary = {}

## Chance of rolling for an event each game day.
const DAILY_CHANCE := 0.55
## Never run more than this many at once; a city with five things happening at
## the same time reads as noise.
const MAX_CONCURRENT := 2


func _ready() -> void:
	EventBus.day_passed.connect(_on_day_passed)
	EventBus.hour_passed.connect(_on_hour_passed)
	SaveManager.register("events", self)


# --- Queries the simulation asks -------------------------------------------

## Combined multiplier on how much residents care about a need right now.
func need_weight(need_type: int) -> float:
	var weight := 1.0
	for entry: Dictionary in active.values():
		var data: EventData = entry["data"]
		weight *= float(data.need_weights.get(need_type, 1.0))
	return weight


## Combined multiplier on how fast a need drains right now.
func decay_multiplier(need_type: int) -> float:
	var multiplier := 1.0
	for entry: Dictionary in active.values():
		var data: EventData = entry["data"]
		multiplier *= float(data.decay_multipliers.get(need_type, 1.0))
	return multiplier


func is_running(event_id: StringName) -> bool:
	return active.has(event_id)


func active_names() -> Array[String]:
	var names: Array[String] = []
	for entry: Dictionary in active.values():
		names.append((entry["data"] as EventData).display_name)
	return names


func count() -> int:
	return active.size()


# --- Running events ---------------------------------------------------------

## Starts an event by id. Public so the player (and the tests) can trigger one
## directly rather than waiting for the dice.
func start(event_id: StringName) -> bool:
	if active.has(event_id):
		return false
	var data := Database.get_event(event_id)
	if data == null:
		return false
	active[event_id] = {
		"data": data,
		"ends_at": GameClock.total_minutes + data.duration_hours * 60.0,
	}
	_pay_out(data)
	EventBus.city_event_started.emit(event_id, data.display_name)
	EventBus.notify("%s: %s" % [data.display_name, data.description])
	return true


func stop(event_id: StringName) -> void:
	if not active.erase(event_id):
		return
	EventBus.city_event_ended.emit(event_id)


func _pay_out(data: EventData) -> void:
	var residents := _resident_count()
	var amount := data.money_on_start + data.money_per_resident * residents
	if amount > 0:
		Economy.earn(amount, data.display_name)
	elif amount < 0:
		# A bill is charged whether or not it can be afforded: the city owes it.
		Economy.money += amount
		EventBus.money_changed.emit(Economy.money, amount)


## Events end on the hour they are due, not the frame — nothing needs finer
## resolution and it keeps the check to once an hour.
func _on_hour_passed(_hour: int) -> void:
	for event_id: StringName in active.keys():
		if GameClock.total_minutes >= float(active[event_id]["ends_at"]):
			stop(event_id)


func _on_day_passed(_day: int) -> void:
	if active.size() >= MAX_CONCURRENT:
		return
	if randf() > DAILY_CHANCE:
		return
	var candidate := _roll()
	if candidate != &"":
		start(candidate)


## Weighted draw among the events that could start right now.
func _roll() -> StringName:
	var hour := GameClock.hour_of_day()
	var residents := _resident_count()
	var pool: Array = []
	var total := 0.0
	for data: EventData in Database.events.values():
		if active.has(data.id) or not data.can_start_at(hour, residents):
			continue
		pool.append(data)
		total += data.weight
	if pool.is_empty() or total <= 0.0:
		return &""
	var pick := randf() * total
	for data: EventData in pool:
		pick -= data.weight
		if pick <= 0.0:
			return data.id
	return (pool[pool.size() - 1] as EventData).id


func _resident_count() -> int:
	var tree := get_tree()
	if tree == null:
		return 0
	var world := tree.get_first_node_in_group(&"world")
	if world == null:
		return 0
	var registry := world.get_node_or_null("Citizens") as CitizenRegistry
	return registry.count() if registry != null else 0


# --- Persistence ------------------------------------------------------------

func save_data() -> Dictionary:
	var entries: Array = []
	for event_id: StringName in active:
		entries.append({"id": String(event_id), "ends_at": float(active[event_id]["ends_at"])})
	return {"active": entries}


func load_data(data: Dictionary) -> void:
	active.clear()
	for entry: Dictionary in (data.get("active", []) as Array):
		var event_id := StringName(entry.get("id", ""))
		var event_data := Database.get_event(event_id)
		if event_data == null:
			continue
		active[event_id] = {"data": event_data, "ends_at": float(entry.get("ends_at", 0.0))}
