class_name RelationshipRegistry
extends Node

## Who knows whom, and how well (design doc §23).
##
## Stored centrally rather than as a list on each citizen, for two reasons: a
## relationship is one fact about a pair, not two facts that can disagree, and a
## city of two hundred residents would otherwise carry two hundred lists that all
## have to be kept in step when somebody moves out.
##
## The value runs -100 (enemies) to +100 (close friends). It is not a hidden
## number: the inspector shows it, and residents behave differently because of
## it — they seek out people they like, which is what turns a house full of
## individuals into a household.

## Pair key "lowId:highId" -> float. One entry per pair, symmetric by
## construction: there is no way to store "A likes B" and "B dislikes A"
## separately, which is exactly the bug this avoids.
var values: Dictionary = {}

## Milestones worth announcing, in ascending order.
const FRIEND_THRESHOLD := 40.0
const CLOSE_THRESHOLD := 75.0
const DISLIKE_THRESHOLD := -30.0

## Where two people who have just met start.
const STRANGER := 0.0
## Living under the same roof is a head start, not a guarantee.
const HOUSEHOLD_BASE := 25.0


func _ready() -> void:
	SaveManager.register("relationships", self)


static func _key(a: int, b: int) -> String:
	return "%d:%d" % [mini(a, b), maxi(a, b)]


func get_value(a: int, b: int) -> float:
	if a == b:
		return 0.0
	return float(values.get(_key(a, b), STRANGER))


func set_value(a: int, b: int, value: float) -> void:
	if a == b:
		return
	values[_key(a, b)] = clampf(value, -100.0, 100.0)


## Moves a relationship and reports the milestones it crosses, so the game can
## tell the player "Anna and Boris are friends now" rather than leaving it in a
## number nobody reads.
func adjust(a: int, b: int, delta: float) -> float:
	if a == b or is_zero_approx(delta):
		return 0.0
	var before := get_value(a, b)
	var after := clampf(before + delta, -100.0, 100.0)
	values[_key(a, b)] = after
	EventBus.relationship_changed.emit(a, b, after)
	_announce_crossing(a, b, before, after)
	return after


func _announce_crossing(a: int, b: int, before: float, after: float) -> void:
	var crossed_up := func(threshold: float) -> bool: return before < threshold and after >= threshold
	if crossed_up.call(CLOSE_THRESHOLD):
		EventBus.notify("%s and %s are close friends now" % [_name_of(a), _name_of(b)])
	elif crossed_up.call(FRIEND_THRESHOLD):
		EventBus.notify("%s and %s have become friends" % [_name_of(a), _name_of(b)])
	elif before > DISLIKE_THRESHOLD and after <= DISLIKE_THRESHOLD:
		EventBus.notify("%s and %s are not getting on" % [_name_of(a), _name_of(b)])


## Everyone this citizen has any relationship with, strongest first.
func relations_of(citizen_id: int) -> Array:
	var result: Array = []
	for key: String in values:
		var parts := key.split(":")
		if parts.size() != 2:
			continue
		var a := int(parts[0])
		var b := int(parts[1])
		if a != citizen_id and b != citizen_id:
			continue
		result.append({"other": b if a == citizen_id else a, "value": float(values[key])})
	result.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		return absf(float(x["value"])) > absf(float(y["value"])))
	return result


func friends_of(citizen_id: int) -> Array:
	var result: Array = []
	for entry: Dictionary in relations_of(citizen_id):
		if float(entry["value"]) >= FRIEND_THRESHOLD:
			result.append(entry)
	return result


## Housemates know each other before the game starts watching them.
func introduce_household(member_ids: Array) -> void:
	for i in member_ids.size():
		for j in range(i + 1, member_ids.size()):
			set_value(int(member_ids[i]), int(member_ids[j]), HOUSEHOLD_BASE)


func forget(citizen_id: int) -> void:
	for key: String in values.keys():
		var parts := key.split(":")
		if parts.size() == 2 and (int(parts[0]) == citizen_id or int(parts[1]) == citizen_id):
			values.erase(key)


func describe(value: float) -> String:
	if value >= CLOSE_THRESHOLD:
		return "close friend"
	if value >= FRIEND_THRESHOLD:
		return "friend"
	if value <= DISLIKE_THRESHOLD:
		return "at odds"
	if value > 5.0:
		return "friendly"
	if value < -5.0:
		return "cool"
	return "acquaintance"


func _name_of(citizen_id: int) -> String:
	var registry := get_parent().get_node_or_null("Citizens") as CitizenRegistry
	if registry == null:
		return "Resident %d" % citizen_id
	var citizen: Citizen = registry.citizens.get(citizen_id)
	return citizen.citizen_name if citizen != null else "Resident %d" % citizen_id


# --- Persistence ------------------------------------------------------------

func save_data() -> Dictionary:
	return {"values": values.duplicate()}


func load_data(data: Dictionary) -> void:
	values.clear()
	var stored: Dictionary = data.get("values", {})
	for key: String in stored.keys():
		values[key] = float(stored[key])
