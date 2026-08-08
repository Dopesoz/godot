class_name ResourcePool
extends RefCounted

## Общий доступ к ресурсам фабрики.
##
## В игре нет «рюкзака игрока»: всё, что построено, оплачивается из складов и
## портов дронов. Это убирает лишний экран инвентаря — на телефоне каждый
## лишний экран стоит дорого — и делает склады осмысленными с первой минуты.

var registry: BuildingRegistry


func _init(building_registry: BuildingRegistry) -> void:
	registry = building_registry


## Хранилища, из которых можно брать и в которые можно класть.
func stores() -> Array[Building]:
	# Массив собирается свой: of_kind() отдаёт кеш реестра по ссылке, и
	# дописывание в него порталось прямо в кеш складов. Склады от этого
	# размножались с каждым вызовом, а вместе с ними двоились и ресурсы.
	var result: Array[Building] = []
	result.append_array(registry.of_kind(BuildingDefs.Kind.STORAGE))
	for kind: int in BuildingDefs.COURIER_KINDS:
		result.append_array(registry.of_kind(kind))
	return result


func count(item_id: StringName) -> int:
	var total: int = 0
	for building: Building in stores():
		if building.output != null:
			total += building.output.count(item_id)
	return total


func has_all(requirements: Dictionary) -> bool:
	for item_id: StringName in requirements:
		if count(item_id) < int(requirements[item_id]):
			return false
	return true


## Чего и сколько не хватает до набора. Пустой словарь — хватает всего.
##
## Отдельный метод, а не «да/нет»: игроку нужно знать не факт нехватки, а
## конкретный недостающий предмет. Именно из-за этого котёл выглядел
## недостижимым — в списке цены было три позиции, и какая из них пустая,
## понять было нельзя.
func missing(requirements: Dictionary) -> Dictionary[StringName, int]:
	var result: Dictionary[StringName, int] = {}
	var available: Dictionary[StringName, int] = totals()
	for item_id: StringName in requirements:
		var shortfall: int = int(requirements[item_id]) - available.get(item_id, 0)
		if shortfall > 0:
			result[item_id] = shortfall
	return result


## Списывает набор целиком либо ничего: недостроенное здание, съевшее половину
## ресурсов, — худший из возможных исходов для игрока.
func take_all(requirements: Dictionary) -> bool:
	if not has_all(requirements):
		return false
	for item_id: StringName in requirements:
		var remaining: int = int(requirements[item_id])
		for building: Building in stores():
			if remaining <= 0:
				break
			if building.output == null:
				continue
			remaining -= building.output.remove(item_id, remaining)
		if remaining > 0:
			# Сюда попасть нельзя: has_all() уже проверил наличие.
			Log.error("ResourcePool: не удалось списать %s (%d осталось)" % [item_id, remaining])
	_notify_changed()
	return true


## Кладёт предметы в первое свободное хранилище. Возвращает непринятый остаток.
func give(item_id: StringName, amount: int) -> int:
	var remaining: int = amount
	for building: Building in stores():
		if remaining <= 0:
			break
		if building.output != null:
			remaining -= building.output.add(item_id, remaining)
	if amount != remaining:
		_notify_changed()
	return remaining


## Сводка по всем хранилищам — её показывает верхняя панель.
func totals() -> Dictionary[StringName, int]:
	var result: Dictionary[StringName, int] = {}
	for building: Building in stores():
		if building.output == null:
			continue
		for item_id: StringName in building.output.item_ids():
			result[item_id] = result.get(item_id, 0) + building.output.count(item_id)
	return result


func total_capacity() -> int:
	var capacity: int = 0
	for building: Building in stores():
		if building.output != null:
			capacity += building.output.capacity
	return capacity


func _notify_changed() -> void:
	Events.inventory_changed.emit(0)
