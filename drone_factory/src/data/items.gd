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
const COAL := &"coal"
const WATER := &"water"
const URANIUM_ORE := &"uranium_ore"
const FUEL_ROD := &"fuel_rod"
const GOLD := &"gold"
const DIAMOND := &"diamond"
const SCIENCE_RED := &"science_red"
const SCIENCE_GREEN := &"science_green"

## Форма иконки: по ней процедурный генератор рисует спрайт предмета.
enum Shape { CHUNK, PLATE, INGOT, GEAR, WIRE, CIRCUIT, DRONE, FLASK, DROPLET, ROD, GEM }

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
	COAL: {
		"name": "Уголь", "shape": Shape.CHUNK,
		"color": Color8(48, 46, 52), "accent": Color8(86, 84, 92), "stack": 200,
	},
	WATER: {
		"name": "Вода", "shape": Shape.DROPLET,
		"color": Palette.WATER_LIGHT, "accent": Color8(150, 210, 255), "stack": 400,
		# Воду не крафтят и не добывают буром — её качает водозабор.
		"from_building": BuildingDefs.WATER_PUMP,
	},
	URANIUM_ORE: {
		"name": "Урановая руда", "shape": Shape.CHUNK,
		"color": Color8(96, 148, 88), "accent": Color8(150, 230, 130), "stack": 200,
	},
	FUEL_ROD: {
		"name": "Топливный стержень", "shape": Shape.ROD,
		"color": Color8(120, 200, 110), "accent": Palette.METAL_LIGHT, "stack": 50,
	},
	GOLD: {
		"name": "Золото", "shape": Shape.INGOT,
		"color": Color8(226, 184, 66), "accent": Color8(255, 226, 140), "stack": 100,
		# Золото не добывается буром и не крафтится: только из упавших метеоритов.
		"from_building": BuildingDefs.WRECK,
	},
	DIAMOND: {
		"name": "Алмаз", "shape": Shape.GEM,
		"color": Color8(168, 226, 255), "accent": Color8(238, 250, 255), "stack": 50,
		"from_building": BuildingDefs.WRECK,
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
	TileTypes.Ore.COAL: COAL,
	TileTypes.Ore.URANIUM: URANIUM_ORE,
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


## Здание, которое производит предмет само, без рецепта (&"" — такого нет).
static func source_building(id: StringName) -> StringName:
	return DEFS.get(id, {}).get("from_building", &"")


## Где взять предмет — одним словом, для подсказок интерфейса.
##
## Без этого игра выглядит тупиковой там, где тупика нет: у котла в цене есть
## кирпич, кирпич доступен с самого начала, но догадаться, что его плавят в
## печи из камня, можно было только перебором рецептов.
static func source_of(id: StringName) -> String:
	var building: StringName = source_building(id)
	if building != &"":
		return BuildingDefs.display_name(building)
	if ORE_TO_ITEM.values().has(id):
		return BuildingDefs.display_name(BuildingDefs.DRILL)
	var recipe: StringName = Recipes.producing(id)
	if recipe == &"":
		return ""
	match Recipes.machine(recipe):
		Recipes.Machine.FURNACE:
			return BuildingDefs.display_name(BuildingDefs.FURNACE)
		Recipes.Machine.ASSEMBLER:
			return BuildingDefs.display_name(BuildingDefs.ASSEMBLER)
		Recipes.Machine.LAB:
			return BuildingDefs.display_name(BuildingDefs.LAB)
		_:
			return ""
