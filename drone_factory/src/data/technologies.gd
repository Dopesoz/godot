class_name Technologies
extends RefCounted

## Дерево технологий.
##
## Каждая технология открывает здания, рецепты или даёт постоянный бонус.
## Дерево намеренно неглубокое: на телефоне играют короткими сессиями, и цель
## должна быть видна на один-два шага вперёд, а не на двадцать.

const WIND_POWER := &"wind_power"
const STEAM_POWER := &"steam_power"
const POWER_STORAGE := &"power_storage"
const MINING_1 := &"mining_1"
const ELECTRONICS := &"electronics"
const STEEL := &"steel"
const DRONE_SPEED := &"drone_speed"
const DRONE_CAPACITY := &"drone_capacity"
const SOLAR_EFFICIENCY := &"solar_efficiency"
const PORT_RANGE := &"port_range"
const MINING_2 := &"mining_2"
const NUCLEAR := &"nuclear"
const DEFENCE := &"defence"
const TURRET_DAMAGE := &"turret_damage"
const FUSION := &"fusion"
const BEACON := &"beacon"

## Ключи бонусов. Значение — прибавка в долях (0.25 = +25%).
const BONUS_MINING_SPEED := &"mining_speed"
const BONUS_DRONE_SPEED := &"drone_speed"
const BONUS_DRONE_CAPACITY := &"drone_capacity"
const BONUS_SOLAR_OUTPUT := &"solar_output"
const BONUS_PORT_RANGE := &"port_range"
const BONUS_TURRET_DAMAGE := &"turret_damage"

## Поля технологии:
##   name        — подпись;
##   cost        — сколько колб нужно;
##   requires    — предшественники;
##   buildings   — какие здания открывает;
##   recipes     — какие рецепты открывает;
##   bonuses     — постоянные прибавки;
##   description — одна строка для панели.
const DEFS: Dictionary[StringName, Dictionary] = {
	MINING_1: {
		"name": "Буры II", "cost": {Items.SCIENCE_RED: 30}, "requires": [],
		"buildings": [], "recipes": [], "bonuses": {BONUS_MINING_SPEED: 0.25},
		"description": "Скорость добычи +25%.",
	},
	WIND_POWER: {
		"name": "Ветроэнергетика", "cost": {Items.SCIENCE_RED: 20}, "requires": [],
		"buildings": [BuildingDefs.WIND], "recipes": [], "bonuses": {},
		"description": "Ветряк: слабее панели, но работает ночью.",
	},
	STEAM_POWER: {
		"name": "Паровая энергия", "cost": {Items.SCIENCE_RED: 25}, "requires": [],
		"buildings": [BuildingDefs.WATER_PUMP, BuildingDefs.BOILER], "recipes": [],
		"bonuses": {},
		"description": "Водозабор и котёл. Много энергии, но копоть.",
	},
	POWER_STORAGE: {
		"name": "Накопление энергии", "cost": {Items.SCIENCE_RED: 40},
		"requires": [], "buildings": [BuildingDefs.ACCUMULATOR], "recipes": [],
		"bonuses": {}, "description": "Открывает аккумулятор: энергия на ночь.",
	},
	ELECTRONICS: {
		"name": "Электроника", "cost": {Items.SCIENCE_RED: 60}, "requires": [],
		"buildings": [], "recipes": [Recipes.CRAFT_CIRCUIT, Recipes.CRAFT_SCIENCE_GREEN],
		"bonuses": {}, "description": "Микросхемы и зелёные колбы.",
	},
	STEEL: {
		"name": "Сталь", "cost": {Items.SCIENCE_RED: 50}, "requires": [],
		"buildings": [], "recipes": [Recipes.SMELT_STEEL], "bonuses": {},
		"description": "Плавка стали в печи.",
	},
	DRONE_SPEED: {
		"name": "Быстрые дроны", "cost": {Items.SCIENCE_RED: 60, Items.SCIENCE_GREEN: 20},
		"requires": [ELECTRONICS], "buildings": [], "recipes": [],
		"bonuses": {BONUS_DRONE_SPEED: 0.35}, "description": "Скорость дронов +35%.",
	},
	DRONE_CAPACITY: {
		"name": "Грузовые дроны", "cost": {Items.SCIENCE_RED: 60, Items.SCIENCE_GREEN: 30},
		"requires": [ELECTRONICS], "buildings": [], "recipes": [Recipes.CRAFT_DRONE],
		"bonuses": {BONUS_DRONE_CAPACITY: 0.5},
		"description": "Сборка дронов, +50% к грузу.",
	},
	SOLAR_EFFICIENCY: {
		"name": "Эффективные панели", "cost": {Items.SCIENCE_RED: 50, Items.SCIENCE_GREEN: 20},
		"requires": [ELECTRONICS], "buildings": [], "recipes": [],
		"bonuses": {BONUS_SOLAR_OUTPUT: 0.3}, "description": "Выработка панелей +30%.",
	},
	PORT_RANGE: {
		"name": "Дальняя логистика", "cost": {Items.SCIENCE_RED: 70, Items.SCIENCE_GREEN: 30},
		"requires": [ELECTRONICS], "buildings": [], "recipes": [],
		"bonuses": {BONUS_PORT_RANGE: 0.4}, "description": "Радиус порта дронов +40%.",
	},
	NUCLEAR: {
		"name": "Атомная энергия",
		"cost": {Items.SCIENCE_RED: 150, Items.SCIENCE_GREEN: 90},
		"requires": [ELECTRONICS, STEEL, STEAM_POWER],
		"buildings": [BuildingDefs.REACTOR], "recipes": [Recipes.CRAFT_FUEL_ROD],
		"bonuses": {},
		"description": "Реактор и стержни. Дорого, зато чисто.",
	},
	BEACON: {
		"name": "Спасательный маяк",
		"cost": {Items.SCIENCE_RED: 140, Items.SCIENCE_GREEN: 80},
		"requires": [ELECTRONICS, STEEL],
		"buildings": [BuildingDefs.BEACON], "recipes": [], "bonuses": {},
		"description": "Передатчик, который позовёт помощь.",
	},
	DEFENCE: {
		"name": "Оборона", "cost": {Items.SCIENCE_RED: 40}, "requires": [],
		"buildings": [BuildingDefs.WALL, BuildingDefs.TURRET],
		"recipes": [Recipes.CRAFT_AMMO], "bonuses": {},
		"description": "Стены, турели и патроны к ним.",
	},
	TURRET_DAMAGE: {
		"name": "Бронебойные патроны",
		"cost": {Items.SCIENCE_RED: 70, Items.SCIENCE_GREEN: 30},
		"requires": [DEFENCE, ELECTRONICS], "buildings": [], "recipes": [],
		"bonuses": {BONUS_TURRET_DAMAGE: 0.75},
		"description": "Урон турелей +75%.",
	},
	FUSION: {
		"name": "Термоядерный синтез",
		"cost": {Items.SCIENCE_RED: 220, Items.SCIENCE_GREEN: 160},
		"requires": [NUCLEAR], "buildings": [BuildingDefs.TRITIUM_PLANT, BuildingDefs.FUSION],
		"recipes": [Recipes.EXTRACT_TRITIUM], "bonuses": {},
		"description": "Тритий из воды и реактор на 2200 кВт.",
	},
	MINING_2: {
		"name": "Буры III", "cost": {Items.SCIENCE_RED: 80, Items.SCIENCE_GREEN: 40},
		"requires": [MINING_1, ELECTRONICS], "buildings": [], "recipes": [],
		"bonuses": {BONUS_MINING_SPEED: 0.5}, "description": "Ещё +50% к скорости добычи.",
	},
}


static func exists(tech_id: StringName) -> bool:
	return DEFS.has(tech_id)


static func get_def(tech_id: StringName) -> Dictionary:
	return DEFS.get(tech_id, {})


static func display_name(tech_id: StringName) -> String:
	return DEFS.get(tech_id, {}).get("name", String(tech_id))


static func description(tech_id: StringName) -> String:
	return DEFS.get(tech_id, {}).get("description", "")


static func cost(tech_id: StringName) -> Dictionary:
	return DEFS.get(tech_id, {}).get("cost", {})


static func requires(tech_id: StringName) -> Array:
	return DEFS.get(tech_id, {}).get("requires", [])


static func buildings(tech_id: StringName) -> Array:
	return DEFS.get(tech_id, {}).get("buildings", [])


static func recipes(tech_id: StringName) -> Array:
	return DEFS.get(tech_id, {}).get("recipes", [])


static func bonuses(tech_id: StringName) -> Dictionary:
	return DEFS.get(tech_id, {}).get("bonuses", {})


static func all_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: StringName in DEFS:
		ids.append(id)
	return ids


## Сколько всего колб нужно на технологию — для полоски прогресса.
static func total_cost(tech_id: StringName) -> int:
	var total: int = 0
	for item_id: StringName in cost(tech_id):
		total += int(cost(tech_id)[item_id])
	return total
