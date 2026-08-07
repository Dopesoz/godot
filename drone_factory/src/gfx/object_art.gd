class_name ObjectArt
extends RefCounted

## Процедурные спрайты зданий, предметов, дронов и значков состояния.
##
## Всё рисуется в один атлас: у объектов один и тот же материал и текстура,
## поэтому вся фабрика уходит в GPU минимальным числом пакетов. Ключ спрайта —
## StringName (id здания или предмета), область в атласе ищется по словарю.

const BADGE_NO_POWER := &"badge_no_power"
const BADGE_NO_INPUT := &"badge_no_input"
const BADGE_FULL := &"badge_full"
const BADGE_NO_ORE := &"badge_no_ore"
const DRONE := &"drone_sprite"
const SELECTION := &"selection"

const BADGE_SIZE: int = 10
const DRONE_SIZE: int = 12
const ICON_SIZE: int = 16


## Возвращает словарь «ключ -> PixelCanvas» со всеми спрайтами объектов.
static func draw_all() -> Dictionary[StringName, PixelCanvas]:
	var sprites: Dictionary[StringName, PixelCanvas] = {}

	for def_id: StringName in BuildingDefs.all_ids():
		sprites[def_id] = _draw_building(def_id)

	for item_id: StringName in Items.all_ids():
		sprites[item_id] = _draw_item(item_id)

	sprites[DRONE] = _draw_drone()
	sprites[SELECTION] = _draw_selection()
	sprites[BADGE_NO_POWER] = _draw_badge(Palette.WARN, "power")
	sprites[BADGE_NO_INPUT] = _draw_badge(Palette.BAD, "input")
	sprites[BADGE_FULL] = _draw_badge(Palette.BAD, "full")
	sprites[BADGE_NO_ORE] = _draw_badge(Palette.UI_TEXT_DIM, "ore")
	return sprites


## --- Здания ----------------------------------------------------------------

static func _draw_building(def_id: StringName) -> PixelCanvas:
	var cells: Vector2i = BuildingDefs.size_of(def_id)
	var canvas := PixelCanvas.new(cells.x * Constants.TILE_SIZE, cells.y * Constants.TILE_SIZE)
	match BuildingDefs.kind(def_id):
		BuildingDefs.Kind.DRILL:
			_draw_drill(canvas)
		BuildingDefs.Kind.FURNACE:
			_draw_furnace(canvas)
		BuildingDefs.Kind.STORAGE:
			_draw_storage(canvas)
		BuildingDefs.Kind.SOLAR:
			_draw_solar(canvas)
		BuildingDefs.Kind.ACCUMULATOR:
			_draw_accumulator(canvas)
		BuildingDefs.Kind.POLE:
			_draw_pole(canvas)
		BuildingDefs.Kind.DRONE_PORT:
			_draw_drone_port(canvas)
		BuildingDefs.Kind.ASSEMBLER:
			_draw_assembler(canvas)
		BuildingDefs.Kind.LAB:
			_draw_lab(canvas)
		_:
			canvas.rect(1, 1, canvas.width - 2, canvas.height - 2, Palette.METAL)
	canvas.outline(Palette.OUTLINE)
	return canvas


## Общая «плита» под механизмом: даёт зданиям единый силуэт.
static func _draw_base(canvas: PixelCanvas, color: Color = Palette.METAL_DARK) -> void:
	canvas.rect(1, 2, canvas.width - 2, canvas.height - 3, color)
	canvas.hline(2, 1, canvas.width - 4, color)
	canvas.hline(2, canvas.height - 1, canvas.width - 4, Palette.OUTLINE)


static func _draw_drill(canvas: PixelCanvas) -> void:
	_draw_base(canvas)
	canvas.rect(3, 4, canvas.width - 6, canvas.height - 8, Palette.METAL)
	# Бурильная головка: конус к центру.
	var cx: int = canvas.width / 2
	for i: int in 5:
		canvas.hline(cx - 3 + i / 2, canvas.height - 8 + i, 6 - i, Palette.ACCENT)
	canvas.rect(cx - 1, 4, 2, canvas.height - 12, Palette.METAL_HILIGHT)
	# Опоры по углам.
	canvas.rect(1, canvas.height - 5, 3, 4, Palette.METAL_DARK)
	canvas.rect(canvas.width - 4, canvas.height - 5, 3, 4, Palette.METAL_DARK)
	canvas.rect_outline(3, 4, canvas.width - 6, canvas.height - 8, Palette.METAL_DARK)


static func _draw_furnace(canvas: PixelCanvas) -> void:
	_draw_base(canvas, Palette.ROCK_DARK)
	canvas.rect(2, 3, canvas.width - 4, canvas.height - 5, Palette.ROCK)
	canvas.speckle(2, 3, canvas.width - 4, canvas.height - 5, Palette.ROCK_LIGHT, 0.12, 31)
	# Топка.
	var fx: int = canvas.width / 2 - 3
	canvas.rect(fx, canvas.height - 10, 6, 5, Palette.OUTLINE)
	canvas.rect(fx + 1, canvas.height - 9, 4, 3, Palette.ACCENT)
	canvas.rect(fx + 2, canvas.height - 8, 2, 1, Palette.WARN)
	# Труба.
	canvas.rect(canvas.width - 7, 1, 4, 5, Palette.METAL_DARK)
	canvas.rect(canvas.width - 6, 0, 2, 2, Palette.METAL)


static func _draw_storage(canvas: PixelCanvas) -> void:
	canvas.rect(1, 2, canvas.width - 2, canvas.height - 3, Palette.DIRT)
	# Доски.
	for x: int in range(2, canvas.width - 2, 4):
		canvas.vline(x, 3, canvas.height - 5, Palette.DIRT_DARK)
	canvas.hline(2, 2, canvas.width - 4, Palette.DIRT_LIGHT)
	# Металлические уголки.
	canvas.rect(1, 2, 3, 3, Palette.METAL)
	canvas.rect(canvas.width - 4, 2, 3, 3, Palette.METAL)
	canvas.rect(1, canvas.height - 4, 3, 3, Palette.METAL)
	canvas.rect(canvas.width - 4, canvas.height - 4, 3, 3, Palette.METAL)
	canvas.rect(canvas.width / 2 - 3, canvas.height / 2 - 2, 6, 4, Palette.ACCENT_DARK)


static func _draw_solar(canvas: PixelCanvas) -> void:
	canvas.rect(1, 2, canvas.width - 2, canvas.height - 3, Palette.METAL_DARK)
	canvas.rect(2, 3, canvas.width - 4, canvas.height - 5, Palette.GLASS_DARK)
	# Сетка ячеек.
	for y: int in range(4, canvas.height - 3, 3):
		canvas.hline(3, y, canvas.width - 6, Palette.METAL_DARK)
	for x: int in range(4, canvas.width - 3, 4):
		canvas.vline(x, 4, canvas.height - 7, Palette.METAL_DARK)
	# Блик.
	canvas.line(Vector2i(4, canvas.height - 5), Vector2i(canvas.width - 6, 4), Palette.GLASS)


static func _draw_accumulator(canvas: PixelCanvas) -> void:
	_draw_base(canvas)
	canvas.rect(3, 3, canvas.width - 6, canvas.height - 6, Palette.METAL)
	canvas.rect(5, 5, canvas.width - 10, canvas.height - 10, Palette.OUTLINE)
	# Шкала заряда.
	for i: int in 3:
		canvas.hline(6, canvas.height - 7 + i * 2, canvas.width - 12, Palette.ENERGY)


static func _draw_pole(canvas: PixelCanvas) -> void:
	var cx: int = canvas.width / 2
	canvas.vline(cx, 2, canvas.height - 3, Palette.DIRT_DARK)
	canvas.vline(cx - 1, 4, canvas.height - 5, Palette.DIRT)
	canvas.hline(cx - 3, 3, 7, Palette.DIRT_DARK)
	canvas.put(cx - 3, 2, Palette.ENERGY)
	canvas.put(cx + 3, 2, Palette.ENERGY)


static func _draw_drone_port(canvas: PixelCanvas) -> void:
	_draw_base(canvas)
	canvas.rect(3, 4, canvas.width - 6, canvas.height - 7, Palette.METAL)
	# Посадочная площадка: круг с крестом.
	var cx: int = canvas.width / 2
	var cy: int = canvas.height / 2
	canvas.circle(cx, cy, canvas.width / 4, Palette.METAL_DARK)
	canvas.hline(cx - 4, cy, 9, Palette.ACCENT)
	canvas.vline(cx, cy - 4, 9, Palette.ACCENT)
	# Антенна.
	canvas.vline(canvas.width - 4, 2, 6, Palette.METAL_HILIGHT)
	canvas.put(canvas.width - 4, 1, Palette.ENERGY)
	# Габаритные огни.
	canvas.put(2, 3, Palette.OK)
	canvas.put(canvas.width - 3, canvas.height - 3, Palette.OK)


static func _draw_assembler(canvas: PixelCanvas) -> void:
	_draw_base(canvas)
	canvas.rect(2, 3, canvas.width - 4, canvas.height - 5, Palette.METAL)
	canvas.rect(4, 5, canvas.width - 8, canvas.height - 9, Palette.METAL_DARK)
	# Шестерня в окне.
	var cx: int = canvas.width / 2
	var cy: int = canvas.height / 2
	canvas.circle(cx, cy, 3, Palette.ACCENT)
	canvas.circle(cx, cy, 1, Palette.METAL_DARK)
	for offset: Vector2i in [Vector2i(4, 0), Vector2i(-4, 0), Vector2i(0, 4), Vector2i(0, -4)]:
		canvas.put(cx + offset.x, cy + offset.y, Palette.ACCENT)
	canvas.hline(2, 2, canvas.width - 4, Palette.METAL_HILIGHT)


static func _draw_lab(canvas: PixelCanvas) -> void:
	_draw_base(canvas)
	canvas.rect(2, 4, canvas.width - 4, canvas.height - 6, Palette.METAL)
	# Стеклянный купол.
	var cx: int = canvas.width / 2
	canvas.circle(cx, 7, 5, Palette.GLASS_DARK)
	canvas.circle(cx, 7, 3, Palette.GLASS)
	canvas.put(cx - 2, 5, Palette.UI_TEXT)
	# Колбы.
	canvas.rect(3, canvas.height - 6, 2, 3, Palette.BAD)
	canvas.rect(canvas.width - 5, canvas.height - 6, 2, 3, Palette.OK)


## --- Предметы --------------------------------------------------------------

static func _draw_item(item_id: StringName) -> PixelCanvas:
	var canvas := PixelCanvas.new(ICON_SIZE, ICON_SIZE)
	var color: Color = Items.color(item_id)
	var accent: Color = Items.accent(item_id)
	match Items.shape(item_id):
		Items.Shape.CHUNK:
			canvas.blob(6, 9, 3.4, color, 11)
			canvas.blob(10, 6, 2.6, color, 23)
			canvas.put(5, 8, accent)
			canvas.put(10, 5, accent)
		Items.Shape.PLATE:
			canvas.rect(2, 6, 12, 5, color)
			canvas.hline(2, 6, 12, accent)
			canvas.hline(3, 10, 10, Palette.OUTLINE)
		Items.Shape.INGOT:
			canvas.rect(3, 7, 10, 5, color)
			canvas.rect(4, 5, 8, 3, color)
			canvas.hline(4, 5, 8, accent)
		Items.Shape.GEAR:
			canvas.circle(8, 8, 5, color)
			canvas.circle(8, 8, 2, accent)
			for offset: Vector2i in [Vector2i(6, 0), Vector2i(-6, 0), Vector2i(0, 6), Vector2i(0, -6),
					Vector2i(4, 4), Vector2i(-4, 4), Vector2i(4, -4), Vector2i(-4, -4)]:
				canvas.rect(8 + offset.x - 1, 8 + offset.y - 1, 2, 2, color)
		Items.Shape.WIRE:
			# Моток из трёх витков: одиночная линия в 16 px на телефоне не читается.
			for i: int in 3:
				var y: int = 4 + i * 3
				canvas.line(Vector2i(2, y + 2), Vector2i(8, y), color)
				canvas.line(Vector2i(8, y), Vector2i(13, y + 2), color)
				canvas.line(Vector2i(2, y + 3), Vector2i(8, y + 1), accent)
			canvas.rect(1, 3, 2, 10, Palette.METAL_DARK)
			canvas.rect(13, 3, 2, 10, Palette.METAL_DARK)
		Items.Shape.CIRCUIT:
			canvas.rect(3, 4, 10, 8, color)
			canvas.rect(5, 6, 6, 4, Palette.METAL_DARK)
			for i: int in 3:
				canvas.hline(2, 5 + i * 3, 2, accent)
				canvas.hline(12, 5 + i * 3, 2, accent)
		Items.Shape.DRONE:
			canvas.rect(6, 7, 4, 3, color)
			canvas.hline(2, 5, 4, accent)
			canvas.hline(10, 5, 4, accent)
			canvas.put(3, 6, Palette.METAL)
			canvas.put(12, 6, Palette.METAL)
		Items.Shape.FLASK:
			canvas.rect(6, 2, 4, 3, Palette.METAL_LIGHT)
			canvas.rect(5, 5, 6, 8, color)
			canvas.hline(6, 6, 4, accent)
			canvas.rect_outline(5, 5, 6, 8, Palette.OUTLINE)
	canvas.outline(Palette.OUTLINE)
	return canvas


## --- Прочее ----------------------------------------------------------------

static func _draw_drone() -> PixelCanvas:
	var canvas := PixelCanvas.new(DRONE_SIZE, DRONE_SIZE)
	# Корпус смотрит вправо: поворот задаётся трансформом при отрисовке.
	canvas.rect(4, 4, 5, 4, Palette.METAL_LIGHT)
	canvas.rect(8, 5, 2, 2, Palette.GLASS)
	# Лопасти.
	canvas.hline(1, 3, 4, Palette.METAL_DARK)
	canvas.hline(1, 9, 4, Palette.METAL_DARK)
	canvas.hline(8, 2, 3, Palette.METAL_DARK)
	canvas.hline(8, 10, 3, Palette.METAL_DARK)
	canvas.put(2, 4, Palette.ACCENT)
	canvas.put(2, 8, Palette.ACCENT)
	canvas.outline(Palette.OUTLINE)
	return canvas


static func _draw_selection() -> PixelCanvas:
	# Уголки выделения: рамка целиком закрывала бы содержимое клетки.
	var canvas := PixelCanvas.new(Constants.TILE_SIZE, Constants.TILE_SIZE)
	var length: int = 5
	for i: int in length:
		canvas.put(i, 0, Palette.ACCENT)
		canvas.put(0, i, Palette.ACCENT)
		canvas.put(Constants.TILE_SIZE - 1 - i, 0, Palette.ACCENT)
		canvas.put(Constants.TILE_SIZE - 1, i, Palette.ACCENT)
		canvas.put(i, Constants.TILE_SIZE - 1, Palette.ACCENT)
		canvas.put(0, Constants.TILE_SIZE - 1 - i, Palette.ACCENT)
		canvas.put(Constants.TILE_SIZE - 1 - i, Constants.TILE_SIZE - 1, Palette.ACCENT)
		canvas.put(Constants.TILE_SIZE - 1, Constants.TILE_SIZE - 1 - i, Palette.ACCENT)
	return canvas


static func _draw_badge(color: Color, symbol: String) -> PixelCanvas:
	var canvas := PixelCanvas.new(BADGE_SIZE, BADGE_SIZE)
	canvas.circle(BADGE_SIZE / 2, BADGE_SIZE / 2, BADGE_SIZE / 2 - 1, Palette.OUTLINE)
	canvas.circle(BADGE_SIZE / 2, BADGE_SIZE / 2, BADGE_SIZE / 2 - 2, color)
	match symbol:
		"power":
			# Молния.
			canvas.line(Vector2i(5, 2), Vector2i(3, 5), Palette.OUTLINE)
			canvas.line(Vector2i(3, 5), Vector2i(6, 5), Palette.OUTLINE)
			canvas.line(Vector2i(6, 5), Vector2i(4, 7), Palette.OUTLINE)
		"input":
			# Стрелка внутрь.
			canvas.vline(4, 2, 4, Palette.OUTLINE)
			canvas.hline(3, 5, 3, Palette.OUTLINE)
		"full":
			# Перечёркнутый квадрат.
			canvas.rect_outline(3, 3, 5, 5, Palette.OUTLINE)
			canvas.line(Vector2i(3, 3), Vector2i(7, 7), Palette.OUTLINE)
		_:
			canvas.rect(4, 3, 2, 4, Palette.OUTLINE)
	return canvas
