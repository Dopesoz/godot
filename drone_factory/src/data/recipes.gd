class_name Recipes
extends RefCounted

## Каталог рецептов. Рецепт описывает, что во что превращается, за какое время
## и на какой машине. Ни печь, ни сборщик не знают конкретных рецептов —
## они лишь исполняют то, что выбрал игрок.

## Виды машин. Строка вида «печь принимает только рецепты печи» — базовое
## правило, из-за которого производство остаётся понятным на маленьком экране.
enum Machine { FURNACE, ASSEMBLER, LAB }

const SMELT_IRON := &"smelt_iron"
const SMELT_COPPER := &"smelt_copper"
const SMELT_BRICK := &"smelt_brick"
const SMELT_STEEL := &"smelt_steel"
const CRAFT_GEAR := &"craft_gear"
const CRAFT_WIRE := &"craft_wire"
const CRAFT_CIRCUIT := &"craft_circuit"
const CRAFT_DRONE := &"craft_drone"
const CRAFT_SCIENCE_RED := &"craft_science_red"
const CRAFT_SCIENCE_GREEN := &"craft_science_green"

## Поля рецепта:
##   name    — подпись в интерфейсе;
##   machine — где исполняется;
##   time    — секунды на одну порцию при полном питании;
##   inputs  — что тратится;
##   outputs — что получается.
const DEFS: Dictionary[StringName, Dictionary] = {
	SMELT_IRON: {
		"name": "Железная пластина", "machine": Machine.FURNACE, "time": 1.6,
		"inputs": {Items.IRON_ORE: 1}, "outputs": {Items.IRON_PLATE: 1},
	},
	SMELT_COPPER: {
		"name": "Медная пластина", "machine": Machine.FURNACE, "time": 1.6,
		"inputs": {Items.COPPER_ORE: 1}, "outputs": {Items.COPPER_PLATE: 1},
	},
	SMELT_BRICK: {
		"name": "Кирпич", "machine": Machine.FURNACE, "time": 2.4,
		"inputs": {Items.STONE: 2}, "outputs": {Items.BRICK: 1},
	},
	SMELT_STEEL: {
		"name": "Сталь", "machine": Machine.FURNACE, "time": 5.0,
		"inputs": {Items.IRON_PLATE: 4}, "outputs": {Items.STEEL: 1},
	},
	CRAFT_GEAR: {
		"name": "Шестерня", "machine": Machine.ASSEMBLER, "time": 1.0,
		"inputs": {Items.IRON_PLATE: 2}, "outputs": {Items.GEAR: 1},
	},
	CRAFT_WIRE: {
		"name": "Медный провод", "machine": Machine.ASSEMBLER, "time": 0.8,
		"inputs": {Items.COPPER_PLATE: 1}, "outputs": {Items.WIRE: 2},
	},
	CRAFT_CIRCUIT: {
		"name": "Микросхема", "machine": Machine.ASSEMBLER, "time": 1.8,
		"inputs": {Items.WIRE: 3, Items.IRON_PLATE: 1}, "outputs": {Items.CIRCUIT: 1},
	},
	CRAFT_DRONE: {
		"name": "Дрон", "machine": Machine.ASSEMBLER, "time": 4.0,
		"inputs": {Items.CIRCUIT: 2, Items.GEAR: 2, Items.STEEL: 1},
		"outputs": {Items.DRONE: 1},
	},
	CRAFT_SCIENCE_RED: {
		"name": "Красная колба", "machine": Machine.ASSEMBLER, "time": 3.0,
		"inputs": {Items.GEAR: 1, Items.COPPER_PLATE: 1},
		"outputs": {Items.SCIENCE_RED: 1},
	},
	CRAFT_SCIENCE_GREEN: {
		"name": "Зелёная колба", "machine": Machine.ASSEMBLER, "time": 5.0,
		"inputs": {Items.CIRCUIT: 1, Items.STEEL: 1},
		"outputs": {Items.SCIENCE_GREEN: 1},
	},
}


static func exists(id: StringName) -> bool:
	return DEFS.has(id)


static func get_def(id: StringName) -> Dictionary:
	return DEFS.get(id, {})


static func display_name(id: StringName) -> String:
	return DEFS.get(id, {}).get("name", String(id))


static func machine(id: StringName) -> int:
	return DEFS.get(id, {}).get("machine", Machine.ASSEMBLER)


static func craft_time(id: StringName) -> float:
	return DEFS.get(id, {}).get("time", 1.0)


static func inputs(id: StringName) -> Dictionary:
	return DEFS.get(id, {}).get("inputs", {})


static func outputs(id: StringName) -> Dictionary:
	return DEFS.get(id, {}).get("outputs", {})


## Все рецепты для указанной машины (в порядке объявления — он же порядок в UI).
static func for_machine(machine_kind: int) -> Array[StringName]:
	var result: Array[StringName] = []
	for id: StringName in DEFS:
		if DEFS[id]["machine"] == machine_kind:
			result.append(id)
	return result


## Первый рецепт, производящий предмет. Нужен подсказкам интерфейса
## («где это делают?») и проверке связности каталога.
static func producing(item_id: StringName) -> StringName:
	for id: StringName in DEFS:
		if DEFS[id]["outputs"].has(item_id):
			return id
	return &""
