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
const PORTER := &"porter_sprite"
const SELECTION := &"selection"

const BADGE_SIZE: int = 10
const DRONE_SIZE: int = 12
## Носильщик ниже дрона по ширине и выше по росту: силуэт человека должен
## читаться с одного взгляда даже при отдалённой камере.
const PORTER_SIZE: Vector2i = Vector2i(8, 12)
const ICON_SIZE: int = 16


## Возвращает словарь «ключ -> PixelCanvas» со всеми спрайтами объектов.
static func draw_all() -> Dictionary[StringName, PixelCanvas]:
	var sprites: Dictionary[StringName, PixelCanvas] = {}

	for def_id: StringName in BuildingDefs.all_ids():
		sprites[def_id] = _draw_building(def_id)

	for item_id: StringName in Items.all_ids():
		sprites[item_id] = _draw_item(item_id)

	sprites[DRONE] = _draw_drone()
	sprites[PORTER] = _draw_porter()
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
		BuildingDefs.Kind.WIND:
			_draw_wind(canvas)
		BuildingDefs.Kind.ACCUMULATOR:
			_draw_accumulator(canvas)
		BuildingDefs.Kind.POLE:
			_draw_pole(canvas)
		BuildingDefs.Kind.DRONE_PORT:
			_draw_drone_port(canvas)
		BuildingDefs.Kind.PORTER_HUT:
			_draw_porter_hut(canvas)
		BuildingDefs.Kind.ASSEMBLER:
			_draw_assembler(canvas)
		BuildingDefs.Kind.WATER_PUMP:
			_draw_water_pump(canvas)
		BuildingDefs.Kind.BOILER:
			_draw_boiler(canvas)
		BuildingDefs.Kind.REACTOR:
			_draw_reactor(canvas)
		BuildingDefs.Kind.BEACON:
			_draw_beacon(canvas)
		BuildingDefs.Kind.WRECK:
			_draw_wreck(canvas)
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


static func _draw_wind(canvas: PixelCanvas) -> void:
	# Бетонная площадка под мачтой: без неё ветряк был почти прозрачным
	# силуэтом и терялся на траве.
	_draw_base(canvas, Palette.ROCK_DARK)
	canvas.rect(2, canvas.height - 7, canvas.width - 4, 6, Palette.ROCK)
	canvas.speckle(2, canvas.height - 7, canvas.width - 4, 6, Palette.ROCK_LIGHT, 0.15, 61)

	var cx: int = canvas.width / 2
	# Мачта с утолщением книзу.
	canvas.rect(cx - 2, canvas.height - 9, 5, 4, Palette.METAL_DARK)
	canvas.rect(cx - 1, 8, 3, canvas.height - 16, Palette.METAL_LIGHT)
	canvas.vline(cx + 1, 8, canvas.height - 16, Palette.METAL)

	# Три лопасти от втулки: силуэт должен читаться даже в 32 пикселя.
	canvas.circle(cx, 8, 2, Palette.METAL_HILIGHT)
	for offset: int in [0, 1]:
		canvas.line(Vector2i(cx + offset, 8), Vector2i(cx + offset, 1), Palette.METAL_HILIGHT)
		canvas.line(Vector2i(cx, 8 + offset), Vector2i(cx - 7, 12 + offset), Palette.METAL_HILIGHT)
		canvas.line(Vector2i(cx, 8 + offset), Vector2i(cx + 7, 12 + offset), Palette.METAL_HILIGHT)
	canvas.put(cx, 0, Palette.GLASS)


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


static func _draw_water_pump(canvas: PixelCanvas) -> void:
	_draw_base(canvas)
	canvas.rect(2, 3, canvas.width - 4, canvas.height - 5, Palette.METAL)
	# Приёмный колодец с водой.
	canvas.rect(3, canvas.height - 8, 7, 6, Palette.WATER_DARK)
	canvas.rect(4, canvas.height - 7, 5, 4, Palette.WATER)
	canvas.hline(4, canvas.height - 7, 5, Palette.WATER_LIGHT)
	# Труба и вентиль.
	canvas.rect(canvas.width - 8, 4, 3, canvas.height - 9, Palette.METAL_LIGHT)
	canvas.hline(canvas.width - 10, 4, 7, Palette.METAL_HILIGHT)
	canvas.circle(canvas.width - 7, 3, 2, Palette.GLASS)


static func _draw_boiler(canvas: PixelCanvas) -> void:
	_draw_base(canvas)
	# Бак.
	canvas.rect(2, 5, canvas.width - 4, canvas.height - 7, Palette.METAL)
	canvas.rect_outline(2, 5, canvas.width - 4, canvas.height - 7, Palette.METAL_DARK)
	canvas.hline(3, 6, canvas.width - 6, Palette.METAL_HILIGHT)
	# Топка с огнём.
	var fx: int = 4
	canvas.rect(fx, canvas.height - 8, 7, 5, Palette.OUTLINE)
	canvas.rect(fx + 1, canvas.height - 7, 5, 3, Palette.ACCENT)
	canvas.rect(fx + 2, canvas.height - 6, 3, 1, Palette.WARN)
	# Труба и дым: сразу видно, что здание коптит.
	canvas.rect(canvas.width - 8, 0, 4, 6, Palette.METAL_DARK)
	canvas.put(canvas.width - 7, 0, Palette.UI_TEXT_DIM)
	canvas.put(canvas.width - 5, 1, Palette.UI_TEXT_DIM)


static func _draw_reactor(canvas: PixelCanvas) -> void:
	_draw_base(canvas)
	canvas.rect(2, 3, canvas.width - 4, canvas.height - 5, Palette.METAL)
	# Купол активной зоны.
	var cx: int = canvas.width / 2
	var cy: int = canvas.height / 2
	canvas.circle(cx, cy, canvas.width / 3, Palette.METAL_DARK)
	canvas.circle(cx, cy, canvas.width / 4, Palette.URANIUM_ORE)
	canvas.circle(cx, cy, 2, Palette.URANIUM_ORE_LIGHT)
	# Символ радиации: три сектора вокруг центра.
	for offset: Vector2i in [Vector2i(0, -6), Vector2i(-5, 4), Vector2i(5, 4)]:
		canvas.rect(cx + offset.x - 1, cy + offset.y - 1, 3, 3, Palette.OUTLINE)
	# Градирни по углам.
	canvas.rect(2, 2, 4, 4, Palette.METAL_LIGHT)
	canvas.rect(canvas.width - 6, 2, 4, 4, Palette.METAL_LIGHT)


static func _draw_beacon(canvas: PixelCanvas) -> void:
	_draw_base(canvas)
	var cx: int = canvas.width / 2
	# Тарелка на мачте: силуэт должен читаться как «передатчик», а не как ещё
	# одна коробка на фабрике.
	canvas.rect(cx - 2, canvas.height - 12, 4, 10, Palette.METAL_LIGHT)
	canvas.line(Vector2i(cx - 7, canvas.height - 3), Vector2i(cx, canvas.height - 11), Palette.METAL)
	canvas.line(Vector2i(cx + 7, canvas.height - 3), Vector2i(cx, canvas.height - 11), Palette.METAL)
	canvas.circle(cx, 10, 7, Palette.METAL_HILIGHT)
	canvas.circle(cx, 10, 5, Palette.GLASS_DARK)
	canvas.circle(cx, 10, 2, Palette.GLASS)
	canvas.put(cx, 2, Palette.ACCENT)
	canvas.put(cx, 3, Palette.ACCENT)


static func _draw_wreck(canvas: PixelCanvas) -> void:
	# Оплавленный обломок в воронке: должен выглядеть как «упало», а не как
	# построено. Поэтому никакой ровной плиты в основании.
	canvas.circle(canvas.width / 2, canvas.height / 2 + 2, canvas.width / 2 - 1, Palette.DIRT_DARK)
	canvas.circle(canvas.width / 2, canvas.height / 2 + 1, canvas.width / 3, Palette.ROCK_DARK)
	canvas.blob(canvas.width / 2, canvas.height / 2, 4.0, Palette.ROCK, 7)
	canvas.blob(canvas.width / 2 - 3, canvas.height / 2 - 2, 2.0, Color8(226, 184, 66), 13)
	canvas.put(canvas.width / 2 + 3, canvas.height / 2 + 1, Color8(168, 226, 255))
	canvas.put(canvas.width / 2 + 2, canvas.height / 2 - 3, Palette.WARN)


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
		Items.Shape.DROPLET:
			# Капля: широкая снизу, острая сверху.
			canvas.put(8, 2, color)
			for i: int in 5:
				canvas.hline(8 - i / 2 - 1, 3 + i, i + 2, color)
			canvas.circle(8, 10, 4, color)
			canvas.put(6, 8, accent)
			canvas.put(7, 7, accent)
		Items.Shape.ROD:
			canvas.rect(6, 2, 4, 12, color)
			canvas.rect(5, 1, 6, 2, Palette.METAL_LIGHT)
			canvas.rect(5, 13, 6, 2, Palette.METAL_LIGHT)
			canvas.vline(7, 4, 8, accent)
		Items.Shape.GEM:
			# Огранённый камень: широкая верхушка и клин вниз.
			canvas.hline(4, 5, 8, accent)
			canvas.hline(3, 6, 10, color)
			for i: int in 5:
				canvas.hline(4 + i, 7 + i, 8 - i * 2, color)
			canvas.put(6, 6, accent)
			canvas.put(9, 8, accent)
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


## Носильщик: маленькая фигурка в комбинезоне с ящиком за спиной.
## Смотрит вправо, отражением получается ход влево.
static func _draw_porter() -> PixelCanvas:
	var canvas := PixelCanvas.new(PORTER_SIZE.x, PORTER_SIZE.y)
	# Каска — самая заметная деталь на фоне травы.
	canvas.rect(2, 1, 4, 2, Palette.ACCENT)
	# Лицо.
	canvas.rect(3, 3, 3, 2, Palette.DIRT_LIGHT)
	# Комбинезон.
	canvas.rect(2, 5, 4, 4, Palette.GLASS_DARK)
	# Ящик за спиной.
	canvas.rect(0, 5, 2, 3, Palette.DIRT)
	# Ноги в шаге.
	canvas.vline(2, 9, 3, Palette.METAL_DARK)
	canvas.vline(5, 9, 2, Palette.METAL_DARK)
	canvas.outline(Palette.OUTLINE)
	return canvas


## Хижина носильщиков: единственная постройка-жильё среди механизмов, поэтому
## силуэт нарочно другой — двускатная крыша, дверь и ящики у стены.
static func _draw_porter_hut(canvas: PixelCanvas) -> void:
	var width: int = canvas.width
	var height: int = canvas.height
	var roof_height: int = height / 2 - 2
	var center: int = width / 2

	# Стены с досками.
	canvas.rect(4, roof_height, width - 8, height - roof_height - 1, Palette.DIRT)
	for x: int in range(6, width - 6, 5):
		canvas.vline(x, roof_height + 1, height - roof_height - 3, Palette.DIRT_DARK)

	# Крыша: треугольник, расширяющийся книзу.
	for row: int in roof_height:
		var half: int = maxi((center - 2) * (row + 1) / roof_height, 1)
		canvas.hline(center - half, 2 + row, half * 2, Palette.DIRT_DARK)
	canvas.hline(center - 1, 1, 2, Palette.OUTLINE)
	canvas.hline(center - roof_height + 2, roof_height + 1, (roof_height - 2) * 2, Palette.OUTLINE)

	# Дверь.
	var door_width: int = maxi(width / 6, 4)
	var door_height: int = height - roof_height - 4
	canvas.rect(center - door_width / 2, height - 1 - door_height, door_width, door_height, Palette.OUTLINE)
	canvas.rect(
		center - door_width / 2 + 1, height - door_height,
		door_width - 2, door_height - 1, Palette.DIRT_LIGHT
	)

	# Ящики у стен: сразу видно, что здание про грузы.
	var box: int = maxi(width / 7, 3)
	for x: int in [5, width - 5 - box] as Array[int]:
		canvas.rect(x, height - 1 - box, box, box, Palette.METAL_DARK)
		canvas.hline(x + 1, height - 1 - box / 2, box - 2, Palette.ACCENT)


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
