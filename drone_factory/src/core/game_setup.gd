class_name GameSetup
extends RefCounted

## Стартовая база новой игры.
##
## Игрок начинает не с пустого поля: порт дронов, склад и запас материалов
## позволяют поставить первый бур в первые же полминуты. Пустой старт на
## телефоне почти всегда означает, что игру закроют.

const STARTING_ITEMS: Dictionary[StringName, int] = {
	Items.STONE: 50,
	Items.IRON_PLATE: 60,
	Items.COPPER_PLATE: 40,
	Items.GEAR: 24,
	Items.CIRCUIT: 8,
	Items.DRONE: 2,
}

## Смещения стартовых построек относительно стартовой клетки.
const PORT_OFFSET := Vector2i(-1, -1)
const STORAGE_OFFSET := Vector2i(3, -1)
const SOLAR_OFFSET := Vector2i(-4, -1)


static func create_starting_base(world: GameWorld) -> void:
	var start: Vector2i = world.start_cell

	var port: Building = _place_near(world, BuildingDefs.DRONE_PORT, start + PORT_OFFSET)
	var storage: Building = _place_near(world, BuildingDefs.STORAGE, start + STORAGE_OFFSET)
	_place_near(world, BuildingDefs.SOLAR, start + SOLAR_OFFSET)

	var chest: Building = storage if storage != null else port
	if chest == null:
		Log.error("GameSetup: не удалось поставить стартовые здания")
		return
	for item_id: StringName in STARTING_ITEMS:
		# Дроны кладём прямо в порт: они должны взлететь сразу, а не ждать,
		# пока игрок догадается перенести их со склада.
		var destination: Building = port if item_id == Items.DRONE and port != null else chest
		destination.output.add(item_id, STARTING_ITEMS[item_id])
	if port != null:
		(port as DronePort).on_world_ready(world.grid)
	Events.inventory_changed.emit(chest.id)


## Ставит здание, при занятости пробуя соседние клетки по спирали: генерация
## могла оставить на месте камень или воду, и старт не должен от этого ломаться.
static func _place_near(world: GameWorld, def_id: StringName, origin: Vector2i) -> Building:
	for radius: int in range(0, 12):
		for dy: int in range(-radius, radius + 1):
			for dx: int in range(-radius, radius + 1):
				if radius > 0 and absi(dx) != radius and absi(dy) != radius:
					continue
				var candidate: Vector2i = origin + Vector2i(dx, dy)
				if world.buildings.can_place(def_id, candidate):
					return world.buildings.place(def_id, candidate)
	Log.warn("GameSetup: не нашлось места для %s" % def_id)
	return null
