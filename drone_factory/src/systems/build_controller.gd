class_name BuildController
extends Node

## Строительство и выбор зданий одним пальцем.
##
## Схема управления: игрок выбирает здание в меню, призрак встаёт в центр
## экрана и следует за картой, пока игрок её двигает. Тап по клетке переносит
## призрак туда, повторный тап (или кнопка «Поставить») подтверждает.
##
## Почему не «тап = сразу построить»: палец закрывает цель, промах стоит
## ресурсов и сноса. Здесь любое действие можно поправить до подтверждения,
## и при этом всё делается одной рукой.

## Доля стоимости, возвращаемая при сносе.
##
## Возвращается всё до копейки, и это осознанный выбор для телефона. Палец
## закрывает цель, промахнуться легко, а штраф за перестройку превращает
## оптимизацию фабрики — то есть главное занятие в игре — в риск. Пусть
## игрок свободно переставляет здания: интересна планировка, а не наказание
## за неудачную.
const REFUND_RATIO: float = 1.0

var world: GameWorld = null
var camera: GameCamera = null
var pool: ResourcePool = null

## Что строим. &"" — режим строительства выключен.
var pending_def_id: StringName = &""
var pending_origin: Vector2i = Vector2i.ZERO
## Призрак следует за центром экрана, пока игрок не ткнул в конкретную клетку.
var follow_center: bool = true

var selected_id: int = 0


func setup(game_world: GameWorld, game_camera: GameCamera) -> void:
	world = game_world
	camera = game_camera
	pool = ResourcePool.new(game_world.buildings)


func _process(_delta: float) -> void:
	if pending_def_id != &"" and follow_center:
		_move_ghost(camera.screen_to_cell(camera.view_size() * 0.5))


## --- Режим строительства ---------------------------------------------------

func start_building(def_id: StringName) -> void:
	if not BuildingDefs.exists(def_id):
		return
	if not world.research.is_building_unlocked(def_id):
		Events.notify.emit("Нужно исследование: %s" % Technologies.display_name(
			BuildingDefs.required_tech(def_id)
		))
		return
	pending_def_id = def_id
	follow_center = true
	select(0)
	_move_ghost(camera.screen_to_cell(camera.view_size() * 0.5))
	Events.build_selection_changed.emit(def_id)


func cancel_building() -> void:
	if pending_def_id == &"":
		return
	pending_def_id = &""
	world.building_renderer.clear_ghost()
	Events.build_selection_changed.emit(&"")


func is_building() -> bool:
	return pending_def_id != &""


## Можно ли поставить прямо сейчас: место и ресурсы.
func can_confirm() -> bool:
	if pending_def_id == &"":
		return false
	if not world.buildings.can_place(pending_def_id, pending_origin):
		return false
	return pool.has_all(BuildingDefs.cost(pending_def_id))


## Причина отказа для интерфейса. Пустая строка — можно строить.
func confirm_blocker() -> String:
	if pending_def_id == &"":
		return ""
	if not world.research.is_building_unlocked(pending_def_id):
		return "Не изучено"
	var error: int = world.buildings.check_placement(pending_def_id, pending_origin)
	if error != BuildingRegistry.PlaceError.OK:
		return BuildingRegistry.placement_error_text(error)
	var missing: Dictionary[StringName, int] = pool.missing(BuildingDefs.cost(pending_def_id))
	if not missing.is_empty():
		# Называем предмет: «не хватает ресурсов» не подсказывает игроку ничего.
		var parts: PackedStringArray = PackedStringArray()
		for item_id: StringName in missing:
			parts.append("%s %d" % [Items.display_name(item_id), missing[item_id]])
		return "Не хватает: " + ", ".join(parts)
	return ""


## Подтверждение постройки. Возвращает поставленное здание или null.
func confirm() -> Building:
	var blocker: String = confirm_blocker()
	if not blocker.is_empty():
		Events.notify.emit(blocker)
		return null

	var def_id: StringName = pending_def_id
	if not pool.take_all(BuildingDefs.cost(def_id)):
		Events.notify.emit("Не хватает ресурсов")
		return null

	var building: Building = world.buildings.place(def_id, pending_origin)
	if building == null:
		# Место занято между проверкой и постановкой — возвращаем оплату.
		_refund(BuildingDefs.cost(def_id), 1.0)
		return null

	Events.notify.emit("%s построен" % BuildingDefs.display_name(def_id))
	# Режим строительства остаётся включённым: подряд ставят по несколько
	# одинаковых зданий, и каждый раз лезть в меню утомительно.
	#
	# У мелочи призрак остаётся на месте: строя забор, игрок идёт вдоль линии,
	# и отбрасывать прицел в центр экрана после каждой клетки — значит мешать
	# ровно тому, ради чего быстрая постановка и сделана.
	if not is_quick_build(def_id):
		follow_center = true
		_move_ghost(camera.screen_to_cell(camera.view_size() * 0.5))
	return building


## Ставится ли здание с одного тапа: мелкое и дешёвое, промах ничего не стоит.
static func is_quick_build(def_id: StringName) -> bool:
	return BuildingDefs.size_of(def_id) == Vector2i.ONE


## --- Жесты -----------------------------------------------------------------

func on_tap(screen_position: Vector2) -> void:
	var cell: Vector2i = camera.screen_to_cell(screen_position)
	if pending_def_id != &"":
		var target: Vector2i = _origin_for_cell(cell)
		# Мелочь вроде забора и столбов ставится с одного тапа.
		#
		# Подтверждение двумя тапами придумано для машин: палец закрывает цель,
		# а промах стоит дорого. У стены из двух кирпичей это не так, зато
		# забор вокруг базы — это полсотни клеток, и по два тапа на каждую
		# превращают оборону в утомительную возню.
		if is_quick_build(pending_def_id):
			follow_center = false
			_move_ghost(target)
			confirm()
			return

		# Первый тап переносит призрак, повторный по тому же месту — ставит.
		if target == pending_origin and not follow_center:
			confirm()
		else:
			follow_center = false
			_move_ghost(target)
		return

	var building: Building = world.buildings.at_cell(cell)
	select(building.id if building != null else 0)


func on_long_press(screen_position: Vector2) -> void:
	if pending_def_id != &"":
		cancel_building()
		Events.notify.emit("Строительство отменено")
		return
	var building: Building = world.buildings.at_cell(camera.screen_to_cell(screen_position))
	if building != null:
		select(building.id)


## --- Выбор и снос ----------------------------------------------------------

func select(building_id: int) -> void:
	if selected_id == building_id:
		return
	selected_id = building_id
	Events.selection_changed.emit(building_id)


func selected() -> Building:
	if selected_id == 0:
		return null
	return world.buildings.get_building(selected_id)


## Снос с частичным возвратом стоимости и содержимого.
func demolish(building_id: int) -> bool:
	var building: Building = world.buildings.get_building(building_id)
	if building == null:
		return false
	var def_id: StringName = building.def_id
	if not BuildingDefs.can_demolish(def_id):
		Events.notify.emit("%s так не разобрать — нужна техника" % BuildingDefs.display_name(def_id))
		return false

	# Танки возвращаются предметами вместе с дронами.
	if building is TankDepot:
		(building as TankDepot).pack_tanks_back()

	# Летающие дроны возвращаются предметами, иначе снос порта их уничтожит.
	if building is DronePort:
		(building as DronePort).pack_drones_back()

	# Сначала спасаем содержимое: терять сотню пластин из-за сноса обидно.
	for inventory: Inventory in [building.input, building.output]:
		if inventory == null:
			continue
		for item_id: StringName in inventory.item_ids():
			pool.give(item_id, inventory.count(item_id))

	if not world.buildings.remove(building_id):
		return false
	if selected_id == building_id:
		select(0)
	_refund(BuildingDefs.cost(def_id), REFUND_RATIO)
	Events.notify.emit("%s разобран" % BuildingDefs.display_name(def_id))
	return true


## --- Внутреннее ------------------------------------------------------------

## Клетка под пальцем — это центр здания, а не его угол: так призрак стоит
## там, куда смотрит игрок.
func _origin_for_cell(cell: Vector2i) -> Vector2i:
	return cell - BuildingDefs.size_of(pending_def_id) / 2


func _move_ghost(origin: Vector2i) -> void:
	pending_origin = origin
	world.building_renderer.set_ghost(
		pending_def_id, origin, world.buildings.can_place(pending_def_id, origin)
	)


func _refund(cost: Dictionary, ratio: float) -> void:
	for item_id: StringName in cost:
		var amount: int = int(floorf(float(cost[item_id]) * ratio))
		if amount > 0:
			pool.give(item_id, amount)
