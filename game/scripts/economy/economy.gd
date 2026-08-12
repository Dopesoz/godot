extends Node

## Autoload: Economy
##
## Player money and the daily bill (design doc §20). Deliberately small: one
## balance, one ledger of recurring costs, no loans or taxes. Every system that
## wants to charge the player goes through `try_spend`, so there is exactly one
## place where "can I afford this?" is answered.

var money: int = 0

## Recurring daily charges, keyed by a string owner id so a demolished building
## can remove its own upkeep without the Economy knowing what a building is.
var _upkeep: Dictionary = {}
## Recurring daily income, same idea (salaries, shop revenue).
var _income: Dictionary = {}


func _ready() -> void:
	money = GameConstants.STARTING_MONEY
	EventBus.day_passed.connect(_on_day_passed)


func can_afford(cost: int) -> bool:
	return money >= cost


## Charges the player if they can pay. Returns whether the caller may proceed —
## callers must respect a false result and not build anything.
func try_spend(cost: int, reason: String = "") -> bool:
	if cost <= 0:
		return true
	if not can_afford(cost):
		EventBus.transaction_rejected.emit(cost, reason)
		return false
	_change(-cost)
	return true


func earn(amount: int, _reason: String = "") -> void:
	if amount <= 0:
		return
	_change(amount)


func _change(delta: int) -> void:
	money += delta
	EventBus.money_changed.emit(money, delta)


func set_upkeep(owner_id: String, amount_per_day: int) -> void:
	if amount_per_day <= 0:
		_upkeep.erase(owner_id)
	else:
		_upkeep[owner_id] = amount_per_day


func set_income(owner_id: String, amount_per_day: int) -> void:
	if amount_per_day <= 0:
		_income.erase(owner_id)
	else:
		_income[owner_id] = amount_per_day


func remove_owner(owner_id: String) -> void:
	_upkeep.erase(owner_id)
	_income.erase(owner_id)


func daily_upkeep() -> int:
	var total := 0
	for amount in _upkeep.values():
		total += int(amount)
	return total


func daily_income() -> int:
	var total := 0
	for amount in _income.values():
		total += int(amount)
	return total


## Settling once per day keeps the balance readable; per-minute trickle income
## would make the number jitter and hide what actually costs money.
func _on_day_passed(_day: int) -> void:
	var net := daily_income() - daily_upkeep()
	if net != 0:
		_change(net)


func save_data() -> Dictionary:
	return {"money": money, "upkeep": _upkeep.duplicate(), "income": _income.duplicate()}


func load_data(data: Dictionary) -> void:
	_upkeep = (data.get("upkeep", {}) as Dictionary).duplicate()
	_income = (data.get("income", {}) as Dictionary).duplicate()
	var new_money := int(data.get("money", GameConstants.STARTING_MONEY))
	var delta := new_money - money
	money = new_money
	EventBus.money_changed.emit(money, delta)
