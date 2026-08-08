class_name PorterHut
extends DronePort

## Хижина носильщиков: наземная логистика ранней игры.
##
## От порта дронов отличается четырьмя вещами, и все четыре — сознательные:
##   * не требует энергии, поэтому работает с первой минуты;
##   * бригада живёт в хижине и не собирается из предметов — отдельный
##     «предмет-носильщик» добавил бы рецепт и экран, а смысла не добавил;
##   * радиус вдвое меньше, груз вчетверо меньше, ход вдвое медленнее —
##     хижина не должна отменять порт дронов, она должна дожить до него;
##   * вместо электричества расходует дерево.
##
## Дерево — это то, ради чего носильщики вообще интересны. Электричество
## тянется проводами и есть везде, где игрок уже построил сеть; древесину надо
## возить, и хижина на дальней залежи превращается в маленькую задачу снабжения
## вместо бесплатной кнопки «доставка есть».
##
## Из этого следует одно правило, без которого схема ломается: оставшись без
## дерева, бригада не встаёт намертво, а берётся только за подвоз дерева себе.
## Иначе хижина в глуши мертва навсегда, и игрок ничего не может с этим сделать.

## Радиус обслуживания в клетках.
const HUT_RADIUS: float = 13.0
## Сколько груза уносит один носильщик за ходку.
const HUT_CARGO: int = 6
## Размер бригады.
const CREW: int = 3
## Сколько дерева сгорает за одну ходку носильщика.
const WOOD_PER_TRIP: int = 1
## Сколько дерева хижина старается держать про запас.
const WOOD_STOCK: int = 30


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
	status = Status.WORKING if has_fuel() else Status.NO_INPUT


func has_fuel() -> bool:
	return input != null and input.count(Items.WOOD) >= WOOD_PER_TRIP


## Хижина просит дерево так же, как машина просит сырьё, — через общий
## механизм запросов. Значит, подвезти его может кто угодно: и дрон соседнего
## порта, и её собственный носильщик.
func requests() -> Dictionary[StringName, int]:
	var needed: Dictionary[StringName, int] = {}
	if not enabled or input == null:
		return needed
	var missing: int = WOOD_STOCK - input.count(Items.WOOD)
	if missing > 0:
		needed[Items.WOOD] = mini(missing, input.free_space())
	return needed


## Без дерева бригада берётся только за одно задание — привезти дерево себе.
func accepts_task(item_id: StringName, target_id: int) -> bool:
	if has_fuel():
		return true
	return item_id == Items.WOOD and target_id == id


## Ходка закончена — дерево сгорело.
func on_courier_returned(_courier: Drone) -> void:
	if input != null:
		input.remove(Items.WOOD, WOOD_PER_TRIP)


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
