class_name DronePort
extends Building

## Порт дронов: база, откуда дроны развозят ресурсы.
##
## Дрон — это предмет: положили в порт — он поднялся в воздух, разобрали порт —
## вернулся предметом на склад. Никакого отдельного экрана управления флотом
## на телефоне не нужно.

## Радиус обслуживания в клетках.
const SERVICE_RADIUS: float = 26.0
## Сколько груза увозит один дрон за рейс.
const CARGO_CAPACITY: int = 20
## Предел дронов на порт: защита и от перегрузки процессора, и от бессмысленных
## пробок над одним складом.
const MAX_DRONES: int = 8

var drones: Array[Drone] = []

var _next_drone_id: int = 1


func service_radius() -> float:
	return SERVICE_RADIUS


func drone_count() -> int:
	return drones.size()


func idle_drones() -> Array[Drone]:
	var result: Array[Drone] = []
	for drone: Drone in drones:
		if not drone.is_busy():
			result.append(drone)
	return result


## Порт работает только под питанием: без энергии дроны стоят на площадке.
func is_operational() -> bool:
	return enabled and power_satisfaction > 0.01


func tick(_delta: float, _context: Dictionary) -> void:
	if not enabled:
		status = Status.DISABLED
		return
	_absorb_drone_items()
	if not is_operational():
		status = Status.NO_POWER
		return
	if drones.is_empty():
		status = Status.IDLE
		return
	status = Status.WORKING


## Превращает предметы-дроны в летающие машины.
func _absorb_drone_items() -> void:
	var stored: int = output.count(Items.DRONE)
	while stored > 0 and drones.size() < MAX_DRONES:
		output.remove(Items.DRONE, 1)
		stored -= 1
		_spawn_drone()
	if drones.size() >= MAX_DRONES and stored > 0:
		# Лишние дроны остаются на складе порта — их можно перевезти в другой.
		pass


func _spawn_drone() -> Drone:
	var drone := Drone.new()
	drone.id = _next_drone_id
	_next_drone_id += 1
	drone.port_id = id
	drone.position = center()
	drone.previous_position = drone.position
	drone.target_position = drone.position
	drones.append(drone)
	Events.drone_count_changed.emit(drones.size(), drones.size())
	return drone


## Возвращает дронов предметами: вызывается перед сносом порта.
func pack_drones_back() -> int:
	var count: int = drones.size()
	for drone: Drone in drones:
		if drone.has_cargo():
			output.add(drone.cargo_item, drone.cargo_count)
	drones.clear()
	output.add(Items.DRONE, count)
	return count


func on_world_ready(_grid: Grid) -> void:
	_absorb_drone_items()


func _serialize_extra() -> Dictionary:
	var list: Array = []
	for drone: Drone in drones:
		list.append(drone.serialize())
	return {"drones": list, "next_id": _next_drone_id}


func _deserialize_extra(data: Dictionary) -> void:
	drones.clear()
	for entry: Variant in data.get("drones", []):
		var drone := Drone.new()
		drone.deserialize(entry)
		drone.port_id = id
		drones.append(drone)
	_next_drone_id = int(data.get("next_id", drones.size() + 1))
