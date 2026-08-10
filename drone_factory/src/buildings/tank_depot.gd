class_name TankDepot
extends Building

## Танковый ангар: дом боевой техники.
##
## Устроен как порт дронов — танк это предмет, который приезжает на склад и
## превращается в машину, — но заданий сам не раздаёт. Приказ идёт от игрока
## через боевую систему, и это принципиально: техника не должна уезжать сама,
## иначе игрок обнаружит потерянную армию, не нажав ни одной кнопки.

const MAX_TANKS: int = 6

var tanks: Array[Tank] = []

var _next_tank_id: int = 1


func tank_count() -> int:
	return tanks.size()


func idle_tanks() -> Array[Tank]:
	var result: Array[Tank] = []
	for tank: Tank in tanks:
		if not tank.is_busy() and tank.is_alive():
			result.append(tank)
	return result


func is_operational() -> bool:
	return enabled and has_power()


func tick(_delta: float, _context: Dictionary) -> void:
	if not enabled:
		status = Status.DISABLED
		return
	_absorb_tank_items()
	if not has_power():
		status = Status.NO_POWER
		return
	status = Status.WORKING if not tanks.is_empty() else Status.IDLE


func requests() -> Dictionary[StringName, int]:
	var needed: Dictionary[StringName, int] = {}
	if not enabled or output == null:
		return needed
	var free_slots: int = MAX_TANKS - tanks.size() - output.count(Items.TANK)
	if free_slots > 0:
		needed[Items.TANK] = mini(free_slots, output.free_space())
	return needed


func _absorb_tank_items() -> void:
	while output.count(Items.TANK) > 0 and tanks.size() < MAX_TANKS:
		output.remove(Items.TANK, 1)
		_spawn_tank()


func _spawn_tank() -> Tank:
	var tank := Tank.new()
	tank.id = _next_tank_id
	_next_tank_id += 1
	tank.depot_id = id
	tank.position = center()
	tank.previous_position = tank.position
	tanks.append(tank)
	return tank


## Разобрали ангар — техника возвращается предметами.
func pack_tanks_back() -> int:
	var count: int = tanks.size()
	tanks.clear()
	output.add(Items.TANK, count)
	return count


func on_world_ready(_grid: Grid) -> void:
	_absorb_tank_items()


func _serialize_extra() -> Dictionary:
	var list: Array = []
	for tank: Tank in tanks:
		list.append(tank.serialize())
	return {"tanks": list, "next_id": _next_tank_id}


func _deserialize_extra(data: Dictionary) -> void:
	tanks.clear()
	for entry: Variant in data.get("tanks", []):
		var tank := Tank.new()
		tank.deserialize(entry)
		tank.depot_id = id
		tanks.append(tank)
	_next_tank_id = int(data.get("next_id", tanks.size() + 1))
