class_name PowerSystem
extends GameSystem

## Электричество: сети, выработка, потребление, аккумуляторы.
##
## Сеть — связная группа зданий: два здания в одной сети, если расстояние между
## их центрами не больше большего из радиусов подключения. Столб ничего не
## потребляет и нужен только чтобы дотянуть сеть до дальнего бура.
##
## Сети пересобираются не каждый тик, а только после постройки или сноса:
## перебор связности стоит заметно дороже самого расчёта мощности, а меняется
## топология редко.
##
## Дефицит распределяется поровну по всем потребителям сети (коэффициент
## удовлетворённости), а не «первым пришёл — первым обслужен»: иначе при
## нехватке энергии часть фабрики вставала бы намертво, и найти причину на
## маленьком экране было бы невозможно.

## Сеть: список зданий и её текущее состояние.
class Network extends RefCounted:
	var building_ids: PackedInt32Array = PackedInt32Array()
	var production: float = 0.0
	var demand: float = 0.0
	var satisfaction: float = 1.0
	var stored: float = 0.0
	var capacity: float = 0.0


var networks: Array[Network] = []

## Суммарные показатели по всем сетям — их показывает верхняя панель.
var total_production: float = 0.0
var total_demand: float = 0.0
var total_satisfaction: float = 1.0
var total_stored: float = 0.0
var total_capacity: float = 0.0

var _dirty: bool = true
var _last_reported := Vector3.ZERO


func system_name() -> String:
	return "энергия"


func _on_setup() -> void:
	if not Events.building_placed.is_connected(_on_topology_changed):
		Events.building_placed.connect(_on_topology_changed)
		Events.building_removed.connect(_on_topology_changed)
	_dirty = true


func reset() -> void:
	networks.clear()
	_dirty = true


func tick(delta: float, context: Dictionary) -> void:
	var registry: BuildingRegistry = context["registry"]
	if _dirty:
		_rebuild_networks(registry)
		_dirty = false

	var daylight: float = context["daylight"]
	total_production = 0.0
	total_demand = 0.0
	total_stored = 0.0
	total_capacity = 0.0
	var weighted_satisfaction: float = 0.0

	for network: Network in networks:
		_update_network(network, registry, daylight, delta)
		total_production += network.production
		total_demand += network.demand
		total_stored += network.stored
		total_capacity += network.capacity
		weighted_satisfaction += network.satisfaction * network.demand

	total_satisfaction = 1.0 if total_demand <= 0.0 else weighted_satisfaction / total_demand
	_report_if_changed()


## --- Расчёт сети -----------------------------------------------------------

func _update_network(network: Network, registry: BuildingRegistry, daylight: float, delta: float) -> void:
	var consumers: Array[Building] = []
	var accumulators: Array[Accumulator] = []

	network.production = 0.0
	network.demand = 0.0
	network.stored = 0.0
	network.capacity = 0.0

	for building_id: int in network.building_ids:
		var building: Building = registry.get_building(building_id)
		if building == null:
			continue
		building.connected = true
		var supply: float = building.power_supply(daylight)
		if supply > 0.0:
			network.production += supply
		var demand: float = building.power_demand()
		if demand > 0.0:
			network.demand += demand
			consumers.append(building)
		if building is Accumulator:
			var accumulator: Accumulator = building
			accumulators.append(accumulator)
			network.stored += accumulator.charge
			network.capacity += accumulator.capacity()

	if network.demand <= 0.0:
		network.satisfaction = 1.0
		_charge_accumulators(accumulators, network.production * delta)
		network.stored = _stored_energy(accumulators)
		return

	var available: float = network.production
	if available < network.demand:
		# Не хватает выработки — добираем из аккумуляторов.
		var needed_energy: float = (network.demand - available) * delta
		var drawn: float = _discharge_accumulators(accumulators, needed_energy)
		available += drawn / maxf(delta, 0.0001)
	elif network.production > network.demand:
		_charge_accumulators(accumulators, (network.production - network.demand) * delta)

	network.satisfaction = clampf(available / network.demand, 0.0, 1.0)
	network.stored = _stored_energy(accumulators)

	for building: Building in consumers:
		building.power_satisfaction = network.satisfaction


static func _charge_accumulators(accumulators: Array[Accumulator], energy: float) -> void:
	if energy <= 0.0 or accumulators.is_empty():
		return
	# Заряд раскладывается поровну: так шкалы на всех аккумуляторах совпадают,
	# и игрок видит одно понятное состояние сети, а не разнобой.
	var share: float = energy / float(accumulators.size())
	var leftover: float = 0.0
	for accumulator: Accumulator in accumulators:
		leftover += share - accumulator.store(share)
	if leftover > 0.001:
		for accumulator: Accumulator in accumulators:
			leftover -= accumulator.store(leftover)
			if leftover <= 0.001:
				break


static func _discharge_accumulators(accumulators: Array[Accumulator], energy: float) -> float:
	if energy <= 0.0 or accumulators.is_empty():
		return 0.0
	var share: float = energy / float(accumulators.size())
	var drawn: float = 0.0
	for accumulator: Accumulator in accumulators:
		drawn += accumulator.draw(share)
	if drawn < energy - 0.001:
		for accumulator: Accumulator in accumulators:
			drawn += accumulator.draw(energy - drawn)
			if drawn >= energy - 0.001:
				break
	return drawn


static func _stored_energy(accumulators: Array[Accumulator]) -> float:
	var total: float = 0.0
	for accumulator: Accumulator in accumulators:
		total += accumulator.charge
	return total


## --- Топология -------------------------------------------------------------

## Сети пересобираются поиском в ширину по «дотягиванию» радиусов.
func _rebuild_networks(registry: BuildingRegistry) -> void:
	networks.clear()

	var members: Array[Building] = []
	for building: Building in registry.all():
		building.connected = false
		building.power_satisfaction = 0.0
		if BuildingDefs.uses_power_network(building.def_id):
			members.append(building)

	var search_range: float = max_power_range()
	var visited: Dictionary[int, bool] = {}
	for building: Building in members:
		if visited.has(building.id):
			continue
		var network := Network.new()
		var queue: Array[Building] = [building]
		visited[building.id] = true
		while not queue.is_empty():
			var current: Building = queue.pop_back()
			network.building_ids.append(current.id)
			var current_range: float = float(BuildingDefs.power_range(current.def_id))
			# Ищем по максимальному радиусу в игре, а связь проверяем по паре:
			# соединение симметрично, хватает радиуса любого из двух зданий.
			# Иначе результат зависел бы от того, с какого здания начат обход.
			for neighbour: Building in registry.in_radius(current.center_cell(), search_range):
				if visited.has(neighbour.id) or not BuildingDefs.uses_power_network(neighbour.def_id):
					continue
				var reach: float = maxf(current_range, float(BuildingDefs.power_range(neighbour.def_id)))
				if current.distance_to(neighbour) > reach:
					continue
				visited[neighbour.id] = true
				queue.append(neighbour)
		networks.append(network)


## Наибольший радиус подключения среди всех зданий: по нему делается
## первичная выборка соседей.
static var _max_power_range: float = -1.0


static func max_power_range() -> float:
	if _max_power_range < 0.0:
		var best: int = BuildingDefs.DEFAULT_CONNECT_RANGE
		for def_id: StringName in BuildingDefs.all_ids():
			best = maxi(best, BuildingDefs.power_range(def_id))
		_max_power_range = float(best)
	return _max_power_range


func _on_topology_changed(_building_id: int) -> void:
	_dirty = true


func mark_dirty() -> void:
	_dirty = true


## --- Отчёт в интерфейс -----------------------------------------------------

## Событие шлём только при заметном изменении: панель обновляется десять раз
## в секунду впустую, если гнать одинаковые числа.
func _report_if_changed() -> void:
	var current := Vector3(
		snappedf(total_production, 1.0),
		snappedf(total_demand, 1.0),
		snappedf(total_satisfaction, 0.05)
	)
	if current == _last_reported:
		return
	_last_reported = current
	Events.power_stats_changed.emit(total_production, total_demand, total_satisfaction)


## Сеть, которой принадлежит здание (или null).
func network_of(building_id: int) -> Network:
	for network: Network in networks:
		if network.building_ids.has(building_id):
			return network
	return null
