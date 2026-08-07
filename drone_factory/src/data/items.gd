class_name Items
extends RefCounted

## Каталог предметов. Данные, а не код: подсистемы обращаются к описаниям,
## а не зашивают знания о конкретных ресурсах.
##
## Идентификаторы — StringName: сравнение по указателю, дешёвый ключ словаря
## и читаемое сохранение (в отличие от числовых id, которые ломаются при
## изменении порядка).

const STONE := &"stone"
const IRON_ORE := &"iron_ore"
const COPPER_ORE := &"copper_ore"
const IRON_PLATE := &"iron_plate"
const COPPER_PLATE := &"copper_plate"
const BRICK := &"brick"
const STEEL := &"steel"
const GEAR := &"gear"
const WIRE := &"wire"
const CIRCUIT := &"circuit"
const DRONE := &"drone"
const SCIENCE_RED := &"science_red"
const SCIENCE_GREEN := &"science_green"

## Форма иконки: по ней процедурный генератор рисует спрайт предмета.
enum Shape { CHUNK, PLATE, INGOT, GEAR, WIRE, CIRCUIT, DRONE, FLASK }

const DEFS: Dictionary[StringName, Dictionary] = {
	STONE: {
		"name": "Камень", "shape": Shape.CHUNK,
		"color": Palette.STONE_ORE, "accent": Palette.STONE_ORE_LIGHT, "stack": 200,
	},
	IRON_ORE: {
		"name": "Железная руда", "shape": Shape.CHUNK,
		"color": Palette.IRON_ORE, "accent": Palette.IRON_ORE_LIGHT, "stack": 200,
	},
	COPPER_ORE: {
		"name": "Медная руда", "shape": Shape.CHUNK,
		"color": Palette.COPPER_ORE, "accent": Palette.COPPER_ORE_LIGHT, "stack": 200,
	},
	IRON_PLATE: {
		"name": "Железная пластина", "shape": Shape.PLATE,
		"color": Palette.METAL_LIGHT, "accent": Palette.METAL_HILIGHT, "stack": 200,
	},
	COPPER_PLATE: {
		"name": "Медная пластина", "shape": Shape.PLATE,
		"color": Palette.COPPER_ORE_LIGHT, "accent": Color8(240, 180, 120), "stack": 200,
	},
	BRICK: {
		"name": "Кирпич", "shape": Shape.INGOT,
		"color": Color8(168, 96, 72), "accent": Color8(198, 126, 96), "stack": 200,
	},
	STEEL: {
		"name": "Сталь", "shape": Shape.INGOT,
		"color": Palette.METAL, "accent": Palette.METAL_HILIGHT, "stack": 100,
	},
	GEAR: {
		"name": "Шестерня", "shape": Shape.GEAR,
		"color": Palette.METAL_LIGHT, "accent": Palette.METAL_DARK, "stack": 100,
	},
	WIRE: {
		"name": "Медный провод", "shape": Shape.WIRE,
		"color": Palette.COPPER_ORE_LIGHT, "accent": Palette.ACCENT, "stack": 200,
	},
	CIRCUIT: {
		"name": "Микросхема", "shape": Shape.CIRCUIT,
		"color": Palette.OK, "accent": Palette.ACCENT, "stack": 100,
	},
	DRONE: {
		"name": "Дрон", "shape": Shape.DRONE,
		"color": Palette.GLASS, "accent": Palette.ACCENT, "stack": 50,
	},
	SCIENCE_RED: {
		"name": "Красная колба", "shape": Shape.FLASK,
		"color": Palette.BAD, "accent": Color8(255, 170, 160), "stack": 100,
	},
	SCIENCE_GREEN: {
		"name": "Зелёная колба", "shape": Shape.FLASK,
		"color": Palette.OK, "accent": Color8(180, 240, 180), "stack": 100,
	},
}

## Предметы, которые добываются буром прямо из земли.
const ORE_TO_ITEM: Dictionary[int, StringName] = {
	TileTypes.Ore.STONE: STONE,
	TileTypes.Ore.IRON: IRON_ORE,
	TileTypes.Ore.COPPER: COPPER_ORE,
}


static func exists(id: StringName) -> bool:
	return DEFS.has(id)


static func display_name(id: StringName) -> String:
	if not DEFS.has(id):
		return String(id)
	return DEFS[id]["name"]


static func color(id: StringName) -> Color:
	if not DEFS.has(id):
		return Palette.UI_TEXT_DIM
	return DEFS[id]["color"]


static func accent(id: StringName) -> Color:
	if not DEFS.has(id):
		return Palette.UI_TEXT
	return DEFS[id]["accent"]


static func shape(id: StringName) -> int:
	if not DEFS.has(id):
		return Shape.CHUNK
	return DEFS[id]["shape"]


static func stack_size(id: StringName) -> int:
	if not DEFS.has(id):
		return 100
	return DEFS[id]["stack"]


static func all_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: StringName in DEFS:
		ids.append(id)
	return ids


## Предмет, который даёт добыча клетки с указанной рудой.
static func from_ore(ore_type: int) -> StringName:
	return ORE_TO_ITEM.get(ore_type, &"")
