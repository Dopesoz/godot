class_name BuildingDefs
extends RefCounted

## Описания зданий: размер, цена, энергия, ёмкости.
##
## Все числа баланса собраны здесь, чтобы настройка не требовала правок кода.
## Размер зданий — минимум 2x2 клетки: на телефоне цель меньше ~9 мм по
## диагонали промахивается пальцем, а 2 клетки при базовом зуме дают ~64 px.

enum Kind {
	STORAGE,
	DRILL,
	FURNACE,
	ASSEMBLER,
	SOLAR,
	WIND,
	ACCUMULATOR,
	POLE,
	DRONE_PORT,
	LAB,
	WATER_PUMP,
	BOILER,
	REACTOR,
	BEACON,
	WRECK,
}

const STORAGE := &"storage"
const DRILL := &"drill"
const FURNACE := &"furnace"
const ASSEMBLER := &"assembler"
const SOLAR := &"solar"
const WIND := &"wind"
const ACCUMULATOR := &"accumulator"
const POLE := &"pole"
const DRONE_PORT := &"drone_port"
const LAB := &"lab"
const WATER_PUMP := &"water_pump"
const BOILER := &"boiler"
const REACTOR := &"reactor"
const BEACON := &"beacon"
const WRECK := &"wreck"

## Поля описания:
##   name          — подпись в интерфейсе;
##   kind          — тип поведения;
##   size          — размер в клетках;
##   cost          — что списывается при постройке;
##   power_use     — потребление, кВт (0 — не потребляет);
##   power_gen     — выработка, кВт (0 — не вырабатывает);
##   power_range   — радиус подключения к сети в клетках;
##   input/output  — ёмкости инвентарей;
##   needs_ore     — требует руду под собой (бур);
##   needs_water   — требует воду вплотную к площадке (насос);
##   player_built  — доступно ли в меню строительства (обломки только падают);
##   pollution     — сколько загрязнения даёт в секунду при работе;
##   tech          — технология, открывающая постройку (&"" — доступно сразу);
##   description   — одна строка для панели информации.
const DEFS: Dictionary[StringName, Dictionary] = {
	STORAGE: {
		"name": "Склад", "kind": Kind.STORAGE, "size": Vector2i(2, 2),
		"cost": {Items.STONE: 20},
		"power_use": 0.0, "power_gen": 0.0, "power_range": 0,
		"input": 0, "output": 600, "needs_ore": false, "tech": &"",
		"description": "Общий склад. Дроны берут отсюда сырьё и складывают готовое.",
	},
	DRILL: {
		"name": "Бур", "kind": Kind.DRILL, "size": Vector2i(2, 2),
		"cost": {Items.IRON_PLATE: 10, Items.GEAR: 4},
		"power_use": 30.0, "power_gen": 0.0, "power_range": 0,
		"input": 0, "output": 50, "needs_ore": true, "tech": &"",
		"description": "Добывает руду из клеток под собой. Нужна энергия.",
	},
	FURNACE: {
		"name": "Печь", "kind": Kind.FURNACE, "size": Vector2i(2, 2),
		"cost": {Items.STONE: 15, Items.IRON_PLATE: 5},
		"power_use": 45.0, "power_gen": 0.0, "power_range": 0,
		"input": 60, "output": 60, "needs_ore": false, "tech": &"",
		"description": "Плавит руду в пластины по выбранному рецепту.",
	},
	ASSEMBLER: {
		"name": "Сборщик", "kind": Kind.ASSEMBLER, "size": Vector2i(2, 2),
		"cost": {Items.IRON_PLATE: 12, Items.GEAR: 6},
		"power_use": 60.0, "power_gen": 0.0, "power_range": 0,
		# Сборщик доступен сразу: красные колбы делаются только в нём, и если
		# запереть его за технологией, игра встанет намертво на первом же шаге.
		"input": 80, "output": 60, "needs_ore": false, "tech": &"",
		"description": "Собирает детали из пластин по выбранному рецепту.",
	},
	SOLAR: {
		"name": "Солнечная панель", "kind": Kind.SOLAR, "size": Vector2i(2, 2),
		"cost": {Items.IRON_PLATE: 8, Items.COPPER_PLATE: 6},
		"power_use": 0.0, "power_gen": 60.0, "power_range": 6,
		"input": 0, "output": 0, "needs_ore": false, "tech": &"",
		"description": "Даёт энергию днём. Ночью питание идёт из аккумуляторов.",
	},
	WIND: {
		"name": "Ветряк", "kind": Kind.WIND, "size": Vector2i(2, 2),
		"cost": {Items.IRON_PLATE: 12, Items.GEAR: 8},
		"power_use": 0.0, "power_gen": 45.0, "power_range": 6,
		"input": 0, "output": 0, "needs_ore": false, "tech": &"wind_power",
		"description": "Слабее панели, но работает и ночью. Зависит от ветра.",
	},
	ACCUMULATOR: {
		"name": "Аккумулятор", "kind": Kind.ACCUMULATOR, "size": Vector2i(2, 2),
		"cost": {Items.IRON_PLATE: 10, Items.COPPER_PLATE: 10},
		"power_use": 0.0, "power_gen": 0.0, "power_range": 6,
		"input": 0, "output": 0, "needs_ore": false, "tech": &"power_storage",
		"description": "Копит энергию днём и отдаёт ночью. Ёмкость 900 кДж.",
	},
	POLE: {
		"name": "Столб", "kind": Kind.POLE, "size": Vector2i(1, 1),
		"cost": {Items.IRON_PLATE: 1},
		"power_use": 0.0, "power_gen": 0.0, "power_range": 9,
		"input": 0, "output": 0, "needs_ore": false, "tech": &"",
		"description": "Расширяет электросеть. Сам энергию не тратит.",
	},
	DRONE_PORT: {
		"name": "Порт дронов", "kind": Kind.DRONE_PORT, "size": Vector2i(3, 3),
		"cost": {Items.IRON_PLATE: 20, Items.CIRCUIT: 4, Items.GEAR: 8},
		"power_use": 25.0, "power_gen": 0.0, "power_range": 0,
		"input": 0, "output": 200, "needs_ore": false, "tech": &"",
		"description": "База дронов. Развозит ресурсы в радиусе действия.",
	},
	WATER_PUMP: {
		"name": "Водозабор", "kind": Kind.WATER_PUMP, "size": Vector2i(2, 2),
		"cost": {Items.IRON_PLATE: 10, Items.GEAR: 4},
		"power_use": 20.0, "power_gen": 0.0, "power_range": 0,
		"input": 0, "output": 200, "needs_ore": false, "needs_water": true,
		"tech": &"steam_power",
		"description": "Ставится у воды. Качает воду для котлов и реакторов.",
	},
	BOILER: {
		"name": "Котёл", "kind": Kind.BOILER, "size": Vector2i(2, 2),
		"cost": {Items.IRON_PLATE: 15, Items.BRICK: 10, Items.GEAR: 5},
		"power_use": 0.0, "power_gen": 110.0, "power_range": 5,
		"input": 120, "output": 0, "needs_ore": false, "tech": &"steam_power",
		"pollution": 1.4,
		"description": "Жжёт уголь с водой. Много энергии, но коптит небо.",
	},
	REACTOR: {
		"name": "Реактор", "kind": Kind.REACTOR, "size": Vector2i(3, 3),
		"cost": {Items.STEEL: 40, Items.CIRCUIT: 30, Items.BRICK: 30, Items.GEAR: 20},
		"power_use": 0.0, "power_gen": 700.0, "power_range": 7,
		"input": 200, "output": 0, "needs_ore": false, "tech": &"nuclear",
		"description": "Один стержень держит фабрику полторы минуты. Без копоти.",
	},
	BEACON: {
		"name": "Маяк", "kind": Kind.BEACON, "size": Vector2i(3, 3),
		"cost": {Items.STEEL: 60, Items.CIRCUIT: 40, Items.GEAR: 30},
		"power_use": 250.0, "power_gen": 0.0, "power_range": 0,
		"input": 0, "output": 0, "needs_ore": false, "tech": &"beacon",
		"description": "Передатчик спасательного сигнала. Нужен постоянный ток.",
	},
	WRECK: {
		"name": "Обломок метеорита", "kind": Kind.WRECK, "size": Vector2i(2, 2),
		"cost": {}, "power_use": 0.0, "power_gen": 0.0, "power_range": 0,
		"input": 0, "output": 120, "needs_ore": false, "tech": &"",
		"player_built": false,
		"description": "Упал с неба. Дроны разберут его на золото и алмазы.",
	},
	LAB: {
		"name": "Лаборатория", "kind": Kind.LAB, "size": Vector2i(2, 2),
		"cost": {Items.IRON_PLATE: 15, Items.GEAR: 10, Items.CIRCUIT: 2},
		"power_use": 55.0, "power_gen": 0.0, "power_range": 0,
		"input": 60, "output": 0, "needs_ore": false, "tech": &"",
		"description": "Тратит колбы на исследования.",
	},
}

## Порядок кнопок в меню строительства: от «поставь первым» к сложному.
const BUILD_ORDER: Array[StringName] = [
	DRILL, FURNACE, STORAGE, SOLAR, WIND, DRONE_PORT, ASSEMBLER, LAB, POLE, ACCUMULATOR,
	WATER_PUMP, BOILER, REACTOR, BEACON,
]

## Ёмкость аккумулятора, кДж.
const ACCUMULATOR_CAPACITY: float = 900.0
## Радиус, в котором любое здание цепляется к сети (без столбов).
const DEFAULT_CONNECT_RANGE: int = 4


static func exists(def_id: StringName) -> bool:
	return DEFS.has(def_id)


static func get_def(def_id: StringName) -> Dictionary:
	return DEFS.get(def_id, {})


static func display_name(def_id: StringName) -> String:
	return DEFS.get(def_id, {}).get("name", String(def_id))


static func kind(def_id: StringName) -> int:
	return DEFS.get(def_id, {}).get("kind", Kind.STORAGE)


static func size_of(def_id: StringName) -> Vector2i:
	return DEFS.get(def_id, {}).get("size", Vector2i.ONE)


static func cost(def_id: StringName) -> Dictionary:
	return DEFS.get(def_id, {}).get("cost", {})


static func power_use(def_id: StringName) -> float:
	return DEFS.get(def_id, {}).get("power_use", 0.0)


static func power_gen(def_id: StringName) -> float:
	return DEFS.get(def_id, {}).get("power_gen", 0.0)


## Радиус подключения к электросети в клетках.
static func power_range(def_id: StringName) -> int:
	var value: int = DEFS.get(def_id, {}).get("power_range", 0)
	return value if value > 0 else DEFAULT_CONNECT_RANGE


static func input_capacity(def_id: StringName) -> int:
	return DEFS.get(def_id, {}).get("input", 0)


static func output_capacity(def_id: StringName) -> int:
	return DEFS.get(def_id, {}).get("output", 0)


static func needs_ore(def_id: StringName) -> bool:
	return DEFS.get(def_id, {}).get("needs_ore", false)


## Требует ли здание воду вплотную к площадке.
## Можно ли построить это здание из меню. Обломки метеоритов только падают.
static func is_player_built(def_id: StringName) -> bool:
	return DEFS.get(def_id, {}).get("player_built", true)


static func needs_water(def_id: StringName) -> bool:
	return DEFS.get(def_id, {}).get("needs_water", false)


## Сколько загрязнения даёт здание в секунду при работе.
static func pollution(def_id: StringName) -> float:
	return DEFS.get(def_id, {}).get("pollution", 0.0)


static func required_tech(def_id: StringName) -> StringName:
	return DEFS.get(def_id, {}).get("tech", &"")


static func description(def_id: StringName) -> String:
	return DEFS.get(def_id, {}).get("description", "")


## Участвует ли здание в электросети (потребляет, вырабатывает или ретранслирует).
static func uses_power_network(def_id: StringName) -> bool:
	var def: Dictionary = DEFS.get(def_id, {})
	if def.is_empty():
		return false
	return (
		float(def["power_use"]) > 0.0
		or float(def["power_gen"]) > 0.0
		or def["kind"] == Kind.POLE
		or def["kind"] == Kind.ACCUMULATOR
	)


static func all_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: StringName in DEFS:
		ids.append(id)
	return ids
