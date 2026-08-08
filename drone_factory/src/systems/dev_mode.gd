class_name DevMode
extends RefCounted

## Режим разработчика: доступ ко всем механикам без прохождения игры.
##
## Нужен, чтобы проверять поздние здания и рецепты, не тратя час на разгон
## фабрики. Живёт отдельным объектом и ничего не меняет в правилах: он только
## вызывает те же публичные операции, что доступны игроку по ходу партии —
## выдаёт материалы на склад и отмечает технологии изученными. Поэтому
## включённый режим не может привести игру в состояние, недостижимое обычным
## путём, и его нельзя случайно оставить включённым «наполовину».
##
## Флаг сознательно не пишется в сохранение: выданные ресурсы и технологии
## сохранятся сами, а вот загружаться в режиме разработчика по умолчанию —
## неприятный сюрприз.

## Сколько каждого предмета выдаётся за одно нажатие.
##
## Двести штук — это пятикратный запас на самое дорогое здание в игре. Больше
## незачем: цель режима — проверить механику, а не забить склады доверху.
const STOCK_PER_ITEM: int = 200
## Предел складов, которые режим достроит под выдачу.
const MAX_EXTRA_STORAGES: int = 16


## Кладёт на склады запас всех предметов, которые вообще бывают в игре.
## Возвращает, сколько наименований удалось разместить.
##
## Под выдачу при необходимости достраиваются склады: без этого «выдать всё»
## упирается в ёмкость стартового сундука и молча выдаёт треть списка —
## худший вид отладочной кнопки, та, которой нельзя верить.
static func grant_all_items(world: GameWorld) -> int:
	if world == null or world.buildings == null:
		return 0
	var pool := ResourcePool.new(world.buildings)
	_ensure_space(world, pool, Items.all_ids().size() * STOCK_PER_ITEM)

	var delivered: int = 0
	for item_id: StringName in Items.all_ids():
		var left: int = pool.give(item_id, STOCK_PER_ITEM)
		if left < STOCK_PER_ITEM:
			delivered += 1
	Events.notify.emit("Выдано наименований: %d" % delivered)
	return delivered


## Достраивает склады, пока свободного места не хватит на всю выдачу.
static func _ensure_space(world: GameWorld, pool: ResourcePool, needed: int) -> void:
	var built: int = 0
	while _free_space(pool) < needed and built < MAX_EXTRA_STORAGES:
		if _place_storage_near(world, world.start_cell) == null:
			break
		built += 1
	if built > 0:
		Log.info("DevMode: под выдачу достроено складов: %d" % built)


static func _free_space(pool: ResourcePool) -> int:
	var free: int = 0
	for building: Building in pool.stores():
		if building.output != null:
			free += building.output.free_space()
	return free


## Ищет свободное место по расширяющемуся кольцу вокруг точки.
static func _place_storage_near(world: GameWorld, center: Vector2i) -> Building:
	for radius: int in range(3, 24):
		for dy: int in range(-radius, radius + 1):
			for dx: int in range(-radius, radius + 1):
				if absi(dx) != radius and absi(dy) != radius:
					continue
				var cell: Vector2i = center + Vector2i(dx, dy)
				if world.buildings.can_place(BuildingDefs.STORAGE, cell):
					return world.buildings.place(BuildingDefs.STORAGE, cell)
	return null


## Отмечает изученными все технологии — вместе с ними открываются здания
## и рецепты, потому что доступность везде спрашивается у ResearchState.
static func unlock_all_research(world: GameWorld) -> int:
	if world == null or world.research == null:
		return 0
	var opened: int = 0
	for tech_id: StringName in Technologies.all_ids():
		if world.research.is_completed(tech_id):
			continue
		world.research.complete(tech_id)
		opened += 1
		Events.research_completed.emit(tech_id)
	if opened > 0:
		Events.unlocks_changed.emit()
	Events.notify.emit("Открыто технологий: %d" % opened)
	return opened


## Мгновенно проходит текущую главу сюжета: иначе поздние главы приходится
## ждать, даже когда всё нужное уже построено.
static func skip_chapter(story: StorySystem) -> bool:
	if story == null or story.is_finished():
		return false
	story.force_advance()
	return true
