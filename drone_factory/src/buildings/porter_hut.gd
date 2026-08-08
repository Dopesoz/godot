class_name PorterHut
extends DronePort

## Хижина носильщиков: наземная логистика ранней игры.
##
## От порта дронов отличается тремя вещами, и все три — сознательные:
##   * не требует энергии, поэтому работает с первой минуты;
##   * бригада живёт в хижине и не собирается из предметов — отдельный
##     «предмет-носильщик» добавил бы рецепт и экран, а смысла не добавил;
##   * радиус вдвое меньше, груз вчетверо меньше, ход вдвое медленнее —
##     хижина не должна отменять порт дронов, она должна дожить до него.

## Радиус обслуживания в клетках.
const HUT_RADIUS: float = 13.0
## Сколько груза уносит один носильщик за ходку.
const HUT_CARGO: int = 6
## Размер бригады.
const CREW: int = 3


func courier_caption() -> String:
	return "Носильщиков: %d" % drone_count()


func service_radius() -> float:
	return HUT_RADIUS * range_multiplier


func cargo_capacity() -> int:
	return int(round(float(HUT_CARGO) * cargo_multiplier))


## Люди работают и без электричества — в этом весь смысл хижины.
func is_operational() -> bool:
	return enabled


func tick(_delta: float, _context: Dictionary) -> void:
	if not enabled:
		status = Status.DISABLED
		return
	_hire_crew()
	status = Status.WORKING


func on_world_ready(_grid: Grid) -> void:
	_hire_crew()


## Бригада всегда полная: носильщики не гибнут и не кончаются.
func _hire_crew() -> void:
	var changed: bool = false
	while drones.size() < CREW:
		_spawn_drone()
		changed = true
	if changed:
		Events.drone_count_changed.emit(drones.size(), drones.size())


## Разбирая хижину, бригада уносит груз в стены — предметов-носильщиков нет.
func pack_drones_back() -> int:
	for porter: Drone in drones:
		if porter.has_cargo():
			output.add(porter.cargo_item, porter.cargo_count)
	var count: int = drones.size()
	drones.clear()
	return count


func _make_courier() -> Drone:
	return Porter.new()
