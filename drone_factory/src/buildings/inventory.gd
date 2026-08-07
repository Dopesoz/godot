class_name Inventory
extends RefCounted

## Хранилище предметов. Один компонент на все здания: буфер бура, вход и выход
## печи, склад, посадочная площадка дронов.
##
## Ёмкость считается в предметах, а не в слотах: на телефоне сетка слотов
## нечитаема и требует мелких касаний, поэтому интерфейс показывает список
## «предмет — количество», а ограничение остаётся одно и понятное.
##
## Класс намеренно «глупый»: никаких сигналов и ссылок на сцену — так его
## можно гонять в тестах тысячами итераций и переиспользовать где угодно.

var capacity: int
## Если список непуст — принимаются только эти предметы (вход печи, склад-фильтр).
var filter: Array[StringName] = []

var _items: Dictionary[StringName, int] = {}
var _total: int = 0


func _init(inventory_capacity: int = 100) -> void:
	capacity = maxi(inventory_capacity, 0)


## --- Запросы ---------------------------------------------------------------

func count(item_id: StringName) -> int:
	return _items.get(item_id, 0)


func total() -> int:
	return _total


func free_space() -> int:
	return maxi(capacity - _total, 0)


func is_empty() -> bool:
	return _total == 0


func is_full() -> bool:
	return _total >= capacity


func accepts(item_id: StringName) -> bool:
	return filter.is_empty() or filter.has(item_id)


## Сколько единиц предмета поместится прямо сейчас.
func space_for(item_id: StringName) -> int:
	if not accepts(item_id):
		return 0
	return free_space()


func has(item_id: StringName, amount: int = 1) -> bool:
	return count(item_id) >= amount


## Хватает ли на весь набор (вход рецепта).
func has_all(requirements: Dictionary) -> bool:
	for item_id: StringName in requirements:
		if count(item_id) < int(requirements[item_id]):
			return false
	return true


## Список предметов в порядке добавления — интерфейс показывает его как есть.
func item_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: StringName in _items:
		ids.append(id)
	return ids


func contents() -> Dictionary[StringName, int]:
	return _items.duplicate()


## --- Изменения -------------------------------------------------------------

## Кладёт предметы. Возвращает, сколько реально поместилось (частичный приём —
## норма: дрон довозит остаток позже).
func add(item_id: StringName, amount: int) -> int:
	if amount <= 0 or not accepts(item_id):
		return 0
	var accepted: int = mini(amount, free_space())
	if accepted <= 0:
		return 0
	_items[item_id] = count(item_id) + accepted
	_total += accepted
	return accepted


## Забирает предметы. Возвращает, сколько реально забрано.
func remove(item_id: StringName, amount: int) -> int:
	if amount <= 0:
		return 0
	var available: int = count(item_id)
	var taken: int = mini(amount, available)
	if taken <= 0:
		return 0
	if taken == available:
		_items.erase(item_id)
	else:
		_items[item_id] = available - taken
	_total -= taken
	return taken


## Списывает весь набор целиком либо не списывает ничего: производство не
## должно съедать половину ингредиентов и застревать.
func consume_all(requirements: Dictionary) -> bool:
	if not has_all(requirements):
		return false
	for item_id: StringName in requirements:
		remove(item_id, int(requirements[item_id]))
	return true


## Помещается ли набор целиком (выход рецепта).
func fits_all(products: Dictionary) -> bool:
	var needed: int = 0
	for item_id: StringName in products:
		if not accepts(item_id):
			return false
		needed += int(products[item_id])
	return needed <= free_space()


func add_all(products: Dictionary) -> bool:
	if not fits_all(products):
		return false
	for item_id: StringName in products:
		add(item_id, int(products[item_id]))
	return true


func clear() -> void:
	_items.clear()
	_total = 0


## --- Сохранение ------------------------------------------------------------

func serialize() -> Dictionary:
	var data: Dictionary = {}
	for id: StringName in _items:
		data[String(id)] = _items[id]
	return data


func deserialize(data: Dictionary) -> void:
	clear()
	for key: Variant in data:
		var id := StringName(key)
		# Предмет мог исчезнуть из каталога после обновления игры — пропускаем,
		# иначе старое сохранение уронит новую версию.
		if not Items.exists(id):
			Log.warn("Инвентарь: неизвестный предмет в сохранении: %s" % id)
			continue
		add(id, int(data[key]))
