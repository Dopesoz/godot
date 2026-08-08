class_name Achievements
extends RefCounted

## Достижения: отметки на пути, которые показывают, что игрок продвинулся.
##
## Все условия описаны данными и проверяются одним и тем же вычислителем, что
## и задачи сюжета. Формулировки конкретные («сто пластин»), а не абстрактные:
## на телефоне игрок должен понимать цель с одного взгляда.

## Виды условий:
##   item   — получено столько-то предмета (добыто + произведено);
##   built  — построено столько-то зданий такого типа;
##   tech   — изучена конкретная технология;
##   techs  — изучено столько-то технологий всего.
##
## У каждого достижения есть награда — небольшая кучка материалов на склад.
## Смысл не в балансе, а в темпе: отметка о прогрессе, которая ничего не даёт,
## на телефоне быстро перестаёт читаться. Награда намеренно меньше стоимости
## следующего шага — она подталкивает, а не заменяет производство.
const DEFS: Dictionary[StringName, Dictionary] = {
	&"first_drill": {
		"name": "Первый бур",
		"description": "Поставьте бур на залежь руды.",
		"condition": {"kind": "built", "def": BuildingDefs.DRILL, "target": 1},
		"reward": {Items.IRON_PLATE: 10, Items.GEAR: 4},
	},
	&"first_smelt": {
		"name": "Первая плавка",
		"description": "Выплавьте железную пластину.",
		"condition": {"kind": "item", "item": Items.IRON_PLATE, "target": 1},
		"reward": {Items.IRON_PLATE: 5},
	},
	&"hundred_plates": {
		"name": "Сотня пластин",
		"description": "Выплавьте 100 железных пластин.",
		"condition": {"kind": "item", "item": Items.IRON_PLATE, "target": 100},
		"reward": {Items.IRON_PLATE: 25, Items.BRICK: 10},
	},
	&"thousand_plates": {
		"name": "Металлургия",
		"description": "Выплавьте 1000 железных пластин.",
		"condition": {"kind": "item", "item": Items.IRON_PLATE, "target": 1000},
		"reward": {Items.STEEL: 20, Items.CIRCUIT: 10},
	},
	&"first_science": {
		"name": "Наука пошла",
		"description": "Соберите первую красную колбу.",
		"condition": {"kind": "item", "item": Items.SCIENCE_RED, "target": 1},
		"reward": {Items.SCIENCE_RED: 10},
	},
	&"first_tech": {
		"name": "Первое открытие",
		"description": "Изучите любую технологию.",
		"condition": {"kind": "techs", "target": 1},
		"reward": {Items.COPPER_PLATE: 15, Items.GEAR: 5},
	},
	&"five_techs": {
		"name": "Исследователь",
		"description": "Изучите пять технологий.",
		"condition": {"kind": "techs", "target": 5},
		"reward": {Items.CIRCUIT: 15, Items.SCIENCE_RED: 20},
	},
	&"circuits": {
		"name": "Электроника",
		"description": "Соберите 50 микросхем.",
		"condition": {"kind": "item", "item": Items.CIRCUIT, "target": 50},
		"reward": {Items.CIRCUIT: 20, Items.WIRE: 30},
	},
	&"steam": {
		"name": "Пар пошёл",
		"description": "Постройте котёл.",
		"condition": {"kind": "built", "def": BuildingDefs.BOILER, "target": 1},
		"reward": {Items.COAL: 40, Items.BRICK: 15},
	},
	&"waterworks": {
		"name": "Водоканал",
		"description": "Накачайте 500 воды.",
		"condition": {"kind": "item", "item": Items.WATER, "target": 500},
		"reward": {Items.BRICK: 20, Items.GEAR: 10},
	},
	&"fleet": {
		"name": "Воздушный флот",
		"description": "Постройте три порта дронов.",
		"condition": {"kind": "built", "def": BuildingDefs.DRONE_PORT, "target": 3},
		"reward": {Items.DRONE: 2, Items.CIRCUIT: 10},
	},
	&"atom": {
		"name": "Мирный атом",
		"description": "Запустите реактор.",
		"condition": {"kind": "built", "def": BuildingDefs.REACTOR, "target": 1},
		"reward": {Items.FUEL_ROD: 2, Items.STEEL: 30},
	},
	&"solar_farm": {
		"name": "Солнечная ферма",
		"description": "Постройте 20 солнечных панелей.",
		"condition": {"kind": "built", "def": BuildingDefs.SOLAR, "target": 20},
		"reward": {Items.COPPER_PLATE: 40, Items.WIRE: 40},
	},
	&"steelworks": {
		"name": "Сталевар",
		"description": "Выплавьте 200 стали.",
		"condition": {"kind": "item", "item": Items.STEEL, "target": 200},
		"reward": {Items.STEEL: 40, Items.CIRCUIT: 20},
	},
}


static func exists(id: StringName) -> bool:
	return DEFS.has(id)


static func display_name(id: StringName) -> String:
	return DEFS.get(id, {}).get("name", String(id))


static func description(id: StringName) -> String:
	return DEFS.get(id, {}).get("description", "")


static func condition(id: StringName) -> Dictionary:
	return DEFS.get(id, {}).get("condition", {})


## Что выдаётся на склад при получении достижения.
static func reward(id: StringName) -> Dictionary:
	return DEFS.get(id, {}).get("reward", {})


## Строка награды для панели достижений.
static func reward_text(id: StringName) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for item_id: StringName in reward(id):
		parts.append("%s %d" % [Items.display_name(item_id), int(reward(id)[item_id])])
	return ", ".join(parts)


static func all_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: StringName in DEFS:
		ids.append(id)
	return ids
