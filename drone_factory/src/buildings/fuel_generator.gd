class_name FuelGenerator
extends Building

## Общая механика генераторов на топливе: котёл и реактор.
##
## Оба жгут порцию топлива вместе с водой и всё это время выдают энергию.
## Отличаются только топливом, временем горения, мощностью и копотью, поэтому
## поведение живёт здесь, а наследники задают лишь числа.

## Остаток горения текущей порции, секунды.
var burn_left: float = 0.0


## Чем питается генератор.
func fuel_item() -> StringName:
	return Items.COAL


## Сколько секунд работает одна порция топлива.
func burn_seconds() -> float:
	return 4.0


## Сколько воды уходит на одну порцию топлива.
func water_per_fuel() -> int:
	return 2


## Сколько топлива и воды генератор просит про запас.
func request_fuel() -> int:
	return 25


func request_water() -> int:
	return 50


func is_burning() -> bool:
	return burn_left > 0.0


func power_supply(_daylight: float) -> float:
	if not enabled or not is_burning():
		return 0.0
	return BuildingDefs.power_gen(def_id)


## Сколько загрязнения генератор даёт в секунду прямо сейчас.
func pollution_rate() -> float:
	return BuildingDefs.pollution(def_id) if is_burning() else 0.0


func tick(delta: float, _context: Dictionary) -> void:
	if not enabled:
		status = Status.DISABLED
		return

	if burn_left > 0.0:
		burn_left = maxf(burn_left - delta, 0.0)
		status = Status.WORKING
		return

	# Порция берётся целиком: топливо без воды сгорело бы впустую, а половина
	# порции оставила бы генератор в подвешенном состоянии.
	var water_needed: int = water_per_fuel()
	if input.count(fuel_item()) >= 1 and input.count(Items.WATER) >= water_needed:
		input.remove(fuel_item(), 1)
		input.remove(Items.WATER, water_needed)
		burn_left = burn_seconds()
		status = Status.WORKING
		Events.inventory_changed.emit(id)
		return
	status = Status.NO_INPUT


func requests() -> Dictionary[StringName, int]:
	var needed: Dictionary[StringName, int] = {}
	if not enabled:
		return needed
	var missing_fuel: int = request_fuel() - input.count(fuel_item())
	if missing_fuel > 0:
		needed[fuel_item()] = mini(missing_fuel, input.free_space())
	var missing_water: int = request_water() - input.count(Items.WATER)
	if missing_water > 0:
		needed[Items.WATER] = mini(missing_water, input.free_space())
	return needed


func _on_setup() -> void:
	if input != null:
		input.filter = [fuel_item(), Items.WATER]


func _serialize_extra() -> Dictionary:
	return {"burn": burn_left}


func _deserialize_extra(data: Dictionary) -> void:
	burn_left = maxf(float(data.get("burn", 0.0)), 0.0)
