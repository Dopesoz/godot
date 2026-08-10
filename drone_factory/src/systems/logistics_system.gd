class_name LogisticsSystem
extends GameSystem

## Автоматическая доставка ресурсов дронами.
##
## Правила простые и одинаковые для всей игры:
##   1. Машина сама ничего не тянет — она публикует запрос (requests()).
##   2. Порт с питанием и свободным дроном ищет запрос в своём радиусе
##      и подбирает поставщика: сначала соседние производители, потом склады.
##   3. Готовую продукцию, которую никто не просит, дроны свозят на склад,
##      иначе бур и печь встают с полным выходом.
##
## Бронирование обязательно: без него два дрона улетают за одним и тем же
## ящиком руды, один возвращается пустым, а машина всё это время стоит.
## Брони живут в системе (не в сохранении) и восстанавливаются из заданий
## дронов при загрузке.

## Сколько ПОПЫТОК раздать задание делаем за тик. Считать нужно именно
## попытки, а не удачи: когда везти нечего, каждый свободный дрон запускает
## полный поиск по окрестностям, и полсотни дронов превращают тик в обход
## всей фабрики. С попытками стоимость тика ограничена сверху.
const MAX_ASSIGN_ATTEMPTS_PER_TICK: int = 6
## Сколько разных баз опрашивается за тик.
##
## Настоящая цена раздачи — запрос «кто рядом» по радиусу базы. Пока все
## попытки за тик доставались одной базе, запрос был один. Честная очередь
## разносит попытки по базам, и без этого предела тик дорожает пропорционально
## числу портов. Очередь от предела не страдает: курсор всё равно сдвигается
## каждый тик, просто круг проходится за несколько тиков вместо одного.
const MAX_BASES_PER_TICK: int = 2
## Насколько заполнен выход производителя, чтобы дроны начали его разгружать.
const HAUL_THRESHOLD: float = 0.25
## Как часто брони пересобираются по заданиям курьеров, в тиках.
##
## Бронь — единственное состояние логистики, которое живёт дольше одного тика,
## и любая утечка в ней означает машину, которой «уже везут» то, что никто не
## везёт. Раз в десять секунд состояние восстанавливается из того, что курьеры
## на самом деле держат в руках, поэтому любая такая ошибка рассасывается сама.
const RESERVATION_AUDIT_TICKS: int = 100

## Забронированные поставки: building_id -> {item -> количество в пути}.
var _incoming: Dictionary[int, Dictionary] = {}
## Забронированный вывоз: building_id -> {item -> количество}.
var _outgoing: Dictionary[int, Dictionary] = {}

var _active_drones: int = 0
var _total_drones: int = 0

## С какого свободного курьера продолжать раздачу заданий.
##
## Попыток на тик немного, а курьеров бывает много. Если каждый тик начинать
## с начала списка, задания достаются одним и тем же, а последние порты и
## хижины стоят без дела — игрок видит ботов, которые просто не летают.
## Курсор пускает раздачу по кругу, и работа доходит до каждого.
var _assign_cursor: int = 0
var _ticks_to_audit: int = RESERVATION_AUDIT_TICKS


func system_name() -> String:
	return "логистика"


func reset() -> void:
	_incoming.clear()
	_outgoing.clear()


func tick(delta: float, context: Dictionary) -> void:
	var registry: BuildingRegistry = context["registry"]
	var research: ResearchState = context.get("research")
	var ports: Array[Building] = courier_bases(registry)

	var active: int = 0
	var total: int = 0
	var attempts: int = 0
	var queried: int = 0
	var base_count: int = ports.size()

	_ticks_to_audit -= 1
	if _ticks_to_audit <= 0:
		_ticks_to_audit = RESERVATION_AUDIT_TICKS
		rebuild_reservations(registry)

	# Обход начинается не с первой базы, а со следующей по кругу. Полёты
	# считаются для всех, а вот попытки раздачи достаются тем, до кого дошла
	# очередь: иначе первый порт съедает весь лимит каждый тик, и дальние
	# порты с хижинами стоят без дела.
	var offset: int = 0 if base_count == 0 else _assign_cursor % base_count
	for step: int in base_count:
		var port: DronePort = ports[(offset + step) % base_count]
		if research != null:
			port.range_multiplier = research.multiplier(Technologies.BONUS_PORT_RANGE)
			port.cargo_multiplier = research.multiplier(Technologies.BONUS_DRONE_CAPACITY)
		total += port.drone_count()
		if not port.is_operational():
			continue

		# Окрестности базы считаем один раз на базу, а не на каждого курьера:
		# запрос по радиусу — самая дорогая операция в этом цикле.
		var neighbours: Array[Building] = []
		var neighbours_ready: bool = false

		for drone: Drone in port.drones:
			if research != null:
				drone.speed_multiplier = research.multiplier(Technologies.BONUS_DRONE_SPEED)
			if drone.is_busy():
				active += 1
				_advance_drone(drone, port, registry, delta)
			elif attempts < MAX_ASSIGN_ATTEMPTS_PER_TICK \
					and (neighbours_ready or queried < MAX_BASES_PER_TICK):
				attempts += 1
				if not neighbours_ready:
					neighbours = registry.in_radius(port.center_cell(), port.service_radius())
					neighbours_ready = true
					queried += 1
				if _assign_task(drone, port, registry, neighbours):
					active += 1

	_assign_cursor += 1

	if active != _active_drones or total != _total_drones:
		_active_drones = active
		_total_drones = total
		Events.drone_count_changed.emit(active, total)


## Все базы курьеров: порты дронов и хижины носильщиков.
static func courier_bases(registry: BuildingRegistry) -> Array[Building]:
	var result: Array[Building] = []
	for kind: int in BuildingDefs.COURIER_KINDS:
		result.append_array(registry.of_kind(kind))
	return result


func active_drones() -> int:
	return _active_drones


func total_drones() -> int:
	return _total_drones


## --- Полёт -----------------------------------------------------------------

func _advance_drone(drone: Drone, port: DronePort, registry: BuildingRegistry, delta: float) -> void:
	if not drone.advance(delta):
		return
	match drone.state:
		Drone.State.TO_SOURCE:
			_pick_up(drone, port, registry)
		Drone.State.TO_TARGET:
			_deliver(drone, port, registry)
		Drone.State.RETURNING:
			_land(drone, port)
		_:
			drone.clear_task()


func _pick_up(drone: Drone, port: DronePort, registry: BuildingRegistry) -> void:
	var source: Building = registry.get_building(drone.source_id)
	_release(_outgoing, drone.source_id, drone.cargo_item, drone.cargo_count)
	if source == null or source.output == null:
		# Поставщика снесли, пока курьер летел. Бронь на приём снимаем здесь же:
		# иначе получатель навсегда останется «тем, кому уже везут», и никто
		# больше не привезёт ему сырьё — машина встанет насовсем.
		_release(_incoming, drone.target_id, drone.cargo_item, drone.cargo_count)
		_return_home(drone, port)
		return

	var taken: int = source.output.remove(drone.cargo_item, drone.cargo_count)
	if taken <= 0:
		# Ресурс успели забрать — бронь снята, дрон возвращается порожняком.
		_release(_incoming, drone.target_id, drone.cargo_item, drone.cargo_count)
		_return_home(drone, port)
		return
	Events.inventory_changed.emit(source.id)

	# Забрали меньше, чем бронировали: лишнюю бронь на приём снимаем.
	if taken < drone.cargo_count:
		_release(_incoming, drone.target_id, drone.cargo_item, drone.cargo_count - taken)
	drone.cargo_count = taken

	var target: Building = registry.get_building(drone.target_id)
	if target == null:
		_return_home(drone, port)
		return
	drone.state = Drone.State.TO_TARGET
	drone.fly_to(target.center())


func _deliver(drone: Drone, port: DronePort, registry: BuildingRegistry) -> void:
	var target: Building = registry.get_building(drone.target_id)
	_release(_incoming, drone.target_id, drone.cargo_item, drone.cargo_count)
	if target == null:
		_return_home(drone, port)
		return

	var inventory: Inventory = target.delivery_inventory()
	var accepted: int = 0 if inventory == null else inventory.add(drone.cargo_item, drone.cargo_count)
	if accepted > 0:
		Events.inventory_changed.emit(target.id)
	drone.cargo_count -= accepted
	if drone.cargo_count <= 0:
		drone.cargo_item = &""
	_return_home(drone, port)


## Дрон возвращается на площадку. Непринятый груз выгружается в порт —
## иначе ресурсы зависли бы в воздухе навсегда.
func _return_home(drone: Drone, port: DronePort) -> void:
	drone.state = Drone.State.RETURNING
	drone.source_id = 0
	drone.target_id = 0
	drone.fly_to(port.center())


func _land(drone: Drone, port: DronePort) -> void:
	if drone.has_cargo() and port.output != null:
		var left: int = drone.cargo_count - port.output.add(drone.cargo_item, drone.cargo_count)
		drone.cargo_count = left
		Events.inventory_changed.emit(port.id)
	if drone.cargo_count <= 0:
		drone.cargo_item = &""
	drone.clear_task()
	port.on_courier_returned(drone)


## --- Раздача заданий -------------------------------------------------------

func _assign_task(
	drone: Drone, port: DronePort, registry: BuildingRegistry, neighbours: Array[Building]
) -> bool:
	# Если дрон почему-то держит груз (например, задание отменили) — сначала
	# отвезём его на склад.
	if drone.has_cargo():
		return _assign_unload(drone, registry, neighbours)

	if _assign_request(drone, port, registry, neighbours):
		return true
	return _assign_haul(drone, port, registry, neighbours)


## Проходим ли курьер весь маршрут: база -> поставщик -> получатель.
## Дрону всё равно, носильщик не пойдёт через воду и такое задание не возьмёт.
static func _route_is_walkable(
	drone: Drone, registry: BuildingRegistry, source: Building, target: Building
) -> bool:
	var home: Vector2 = drone.position
	return (
		drone.can_travel(registry.grid, home, source.center())
		and drone.can_travel(registry.grid, source.center(), target.center())
	)


## Что вообще лежит в окрестностях базы.
##
## Считается один раз на попытку и заменяет обход соседей ради каждого
## запроса. Разница видна там, где просят то, чего рядом нет: порт постоянно
## просит дронов, и без этого списка каждый такой запрос запускал полный обход
## окрестностей впустую — на фабрике с десятками портов это заметная доля тика.
static func _available_items(neighbours: Array[Building]) -> Dictionary[StringName, bool]:
	var available: Dictionary[StringName, bool] = {}
	for candidate: Building in neighbours:
		if candidate.output == null:
			continue
		for item_id: StringName in candidate.output.item_ids():
			available[item_id] = true
	return available


## Задание «привезти сырьё тому, кто просит».
func _assign_request(
	drone: Drone, port: DronePort, registry: BuildingRegistry, neighbours: Array[Building]
) -> bool:
	var on_hand: Dictionary[StringName, bool] = _available_items(neighbours)
	if on_hand.is_empty():
		return false
	for consumer: Building in neighbours:
		var requests: Dictionary[StringName, int] = consumer.requests()
		for item_id: StringName in requests:
			# Просят то, чего рядом нет, — обходить соседей ради этого незачем.
			if not on_hand.has(item_id):
				continue
			var needed: int = int(requests[item_id]) - _reserved(_incoming, consumer.id, item_id)
			if needed <= 0:
				continue
			var amount: int = mini(needed, port.cargo_capacity())
			var source: Building = _find_source(registry, neighbours, item_id, consumer.id, amount)
			if source == null:
				continue
			var available: int = source.output.count(item_id) - _reserved(_outgoing, source.id, item_id)
			amount = mini(amount, available)
			if amount <= 0:
				continue
			if not port.accepts_task(item_id, consumer.id):
				continue
			if not _route_is_walkable(drone, registry, source, consumer):
				continue
			_start_task(drone, port, source, consumer, item_id, amount)
			return true
	return false


## Задание «разгрузить производителя на склад».
func _assign_haul(
	drone: Drone, port: DronePort, registry: BuildingRegistry, neighbours: Array[Building]
) -> bool:
	for producer: Building in neighbours:
		if producer.output == null or producer.output.is_empty():
			continue
		if BuildingDefs.kind(producer.def_id) in [
			BuildingDefs.Kind.STORAGE, BuildingDefs.Kind.DRONE_PORT
		]:
			continue
		# Разгружаем не сразу, а когда выход заметно наполнился: иначе дроны
		# мотаются туда-сюда с одной пластиной и мешают полезным рейсам.
		if float(producer.output.total()) < float(producer.output.capacity) * HAUL_THRESHOLD:
			continue
		for item_id: StringName in producer.output.item_ids():
			var available: int = producer.output.count(item_id) - _reserved(_outgoing, producer.id, item_id)
			if available <= 0:
				continue
			var amount: int = mini(available, port.cargo_capacity())
			var storage: Building = _find_storage(neighbours, item_id, amount)
			if storage == null:
				continue
			if not port.accepts_task(item_id, storage.id):
				continue
			if not _route_is_walkable(drone, registry, producer, storage):
				continue
			_start_task(drone, port, producer, storage, item_id, amount)
			return true
	return false


## Дрон с «осиротевшим» грузом просто везёт его на склад.
func _assign_unload(
	drone: Drone, registry: BuildingRegistry, neighbours: Array[Building]
) -> bool:
	var storage: Building = _find_storage(neighbours, drone.cargo_item, drone.cargo_count)
	if storage == null:
		return false
	if not drone.can_travel(registry.grid, drone.position, storage.center()):
		return false
	drone.state = Drone.State.TO_TARGET
	drone.target_id = storage.id
	drone.fly_to(storage.center())
	_reserve(_incoming, storage.id, drone.cargo_item, drone.cargo_count)
	return true


func _start_task(
	drone: Drone, port: DronePort, source: Building, target: Building,
	item_id: StringName, amount: int
) -> void:
	drone.state = Drone.State.TO_SOURCE
	drone.source_id = source.id
	drone.target_id = target.id
	drone.cargo_item = item_id
	drone.cargo_count = amount
	drone.position = port.center()
	drone.previous_position = drone.position
	drone.fly_to(source.center())
	_reserve(_outgoing, source.id, item_id, amount)
	_reserve(_incoming, target.id, item_id, amount)


## Поставщик предмета: сначала производители (свежая продукция), потом склады.
## Так печь получает пластины прямо от соседней печи, не гоняя их через склад.
func _find_source(
	_registry: BuildingRegistry, neighbours: Array[Building],
	item_id: StringName, exclude_id: int, amount: int
) -> Building:
	var storage_fallback: Building = null
	for candidate: Building in neighbours:
		if candidate.id == exclude_id or candidate.output == null:
			continue
		var available: int = candidate.output.count(item_id) - _reserved(_outgoing, candidate.id, item_id)
		if available <= 0:
			continue
		if BuildingDefs.kind(candidate.def_id) in [
			BuildingDefs.Kind.STORAGE, BuildingDefs.Kind.DRONE_PORT
		]:
			if storage_fallback == null:
				storage_fallback = candidate
			continue
		if available >= mini(amount, 1):
			return candidate
	return storage_fallback


func _find_storage(neighbours: Array[Building], item_id: StringName, amount: int) -> Building:
	for candidate: Building in neighbours:
		if BuildingDefs.kind(candidate.def_id) != BuildingDefs.Kind.STORAGE:
			continue
		if candidate.output == null:
			continue
		var free: int = candidate.output.free_space() - _reserved(_incoming, candidate.id, item_id)
		if free >= mini(amount, 1) and candidate.output.accepts(item_id):
			return candidate
	return null


## --- Брони -----------------------------------------------------------------

static func _reserved(table: Dictionary[int, Dictionary], building_id: int, item_id: StringName) -> int:
	return table.get(building_id, {}).get(item_id, 0)


static func _reserve(
	table: Dictionary[int, Dictionary], building_id: int, item_id: StringName, amount: int
) -> void:
	if amount <= 0:
		return
	var entry: Dictionary = table.get(building_id, {})
	entry[item_id] = int(entry.get(item_id, 0)) + amount
	table[building_id] = entry


static func _release(
	table: Dictionary[int, Dictionary], building_id: int, item_id: StringName, amount: int
) -> void:
	if amount <= 0 or not table.has(building_id):
		return
	var entry: Dictionary = table[building_id]
	var left: int = int(entry.get(item_id, 0)) - amount
	if left > 0:
		entry[item_id] = left
	else:
		entry.erase(item_id)
	if entry.is_empty():
		table.erase(building_id)
	else:
		table[building_id] = entry


## Восстанавливает брони по заданиям дронов: после загрузки сохранения дроны
## уже в пути, и система обязана знать об их грузах.
func rebuild_reservations(registry: BuildingRegistry) -> void:
	_incoming.clear()
	_outgoing.clear()
	for port_building: Building in courier_bases(registry):
		for drone: Drone in (port_building as DronePort).drones:
			if drone.cargo_count <= 0 or drone.cargo_item == &"":
				continue
			if drone.state == Drone.State.TO_SOURCE:
				_reserve(_outgoing, drone.source_id, drone.cargo_item, drone.cargo_count)
			if drone.state == Drone.State.TO_SOURCE or drone.state == Drone.State.TO_TARGET:
				_reserve(_incoming, drone.target_id, drone.cargo_item, drone.cargo_count)
