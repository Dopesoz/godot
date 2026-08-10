class_name ItemInfo
extends RefCounted

## Справка по предмету: откуда берётся, куда идёт, сколько его осталось.
##
## Отдельный объект, а не метод панели: те же ответы нужны подсказкам при
## строительстве и тестам, а знание «где применяется медный провод» — это
## свойство каталога, а не экрана.
##
## Запасы в земле считаются одним проходом по слою руды. Проход по четверти
## миллиона клеток стоит несколько миллисекунд, поэтому результат кешируется:
## игрок открывает справку куда чаще, чем меняются недра.

## Как долго держится подсчёт запасов, секунды.
const RESERVE_CACHE_SECONDS: float = 5.0

static var _reserves: Dictionary[StringName, int] = {}
static var _reserves_at: float = -1000.0


## Рецепты, в которых предмет — сырьё.
static func used_in(item_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for recipe_id: StringName in Recipes.DEFS:
		if Recipes.inputs(recipe_id).has(item_id):
			result.append(recipe_id)
	return result


## Здания, в стоимость которых входит предмет.
static func builds(item_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for def_id: StringName in BuildingDefs.BUILD_ORDER:
		if BuildingDefs.cost(def_id).has(item_id):
			result.append(def_id)
	return result


## Технологии, которые изучаются за этот предмет (колбы).
static func researches(item_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for tech_id: StringName in Technologies.all_ids():
		if Technologies.cost(tech_id).has(item_id):
			result.append(tech_id)
	return result


## Здания, которые сжигают предмет как топливо или сырьё, но без рецепта:
## котёл, реактор, турель, хижина носильщиков.
static func consumed_by(item_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for def_id: StringName in BuildingDefs.BUILD_ORDER:
		if FUEL_USERS.get(def_id, []).has(item_id):
			result.append(def_id)
	return result


## Что чем питается — то, чего нет в рецептах, потому что эти здания работают
## без выбора рецепта.
const FUEL_USERS: Dictionary[StringName, Array] = {
	BuildingDefs.BOILER: [Items.COAL, Items.WATER],
	BuildingDefs.REACTOR: [Items.FUEL_ROD, Items.WATER],
	BuildingDefs.FUSION: [Items.TRITIUM, Items.WATER],
	BuildingDefs.TURRET: [Items.AMMO],
	BuildingDefs.PORTER_HUT: [Items.WOOD],
	BuildingDefs.DRONE_PORT: [Items.DRONE],
	BuildingDefs.TANK_DEPOT: [Items.TANK],
}


## Можно ли обменять предмет на науку. Так живут находки с метеоритов: они
## не участвуют ни в одном рецепте, зато сразу превращаются в колбы.
static func tradable(item_id: StringName) -> bool:
	return ResearchSystem.TRADE_RATES.has(item_id)


## Сколько предмета ещё лежит в земле по всей карте. -1 — предмет не добывается.
static func reserves(grid: Grid, item_id: StringName) -> int:
	if grid == null:
		return -1
	var ore_type: int = -1
	for candidate: int in Items.ORE_TO_ITEM:
		if Items.ORE_TO_ITEM[candidate] == item_id:
			ore_type = candidate
			break
	if ore_type < 0:
		return -1
	_refresh_reserves(grid)
	return _reserves.get(item_id, 0)


## Пересчёт запасов — один проход по слою руды на все виды сразу.
static func _refresh_reserves(grid: Grid) -> void:
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	if now - _reserves_at < RESERVE_CACHE_SECONDS:
		return
	_reserves_at = now

	var totals: Dictionary[int, int] = {}
	var count: int = grid.size * grid.size
	var ore: PackedByteArray = grid.ore
	var amount: PackedInt32Array = grid.ore_amount
	for i: int in count:
		var kind: int = ore[i]
		if kind == TileTypes.Ore.NONE:
			continue
		totals[kind] = totals.get(kind, 0) + amount[i]

	_reserves.clear()
	for kind: int in totals:
		var id: StringName = Items.ORE_TO_ITEM.get(kind, &"")
		if id != &"":
			_reserves[id] = totals[kind]


## Сбрасывает кеш запасов: новая партия — другие недра.
static func forget_reserves() -> void:
	_reserves.clear()
	_reserves_at = -1000.0
