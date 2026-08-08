class_name PowerGauges
extends Node2D

## Шкала выработки над каждым энергетическим зданием.
##
## Раньше узнать, сколько даёт конкретная панель, можно было только тапнув по
## ней: общий счётчик в HUD показывает сумму по всей фабрике, а сумма не
## отвечает на главный вопрос планировки — какое из зданий сейчас простаивает.
## Теперь ответ виден прямо на карте.
##
## Отдельный слой, а не часть отрисовки зданий, по двум причинам. Слой зданий
## перерисовывается только при изменениях и обходит все видимые постройки;
## выработка же меняется непрерывно, и привязывать к ней перерисовку всей
## фабрики значило бы терять её главную оптимизацию. Здесь перерисовываются
## только генераторы и только несколько раз в секунду.

## Как часто обновляются цифры. Чаще человек всё равно не читает, а каждая
## перерисовка — это обход генераторов и работа с текстом.
const REFRESH_INTERVAL: float = 0.25
## Шире этого (в клетках) шкалы не рисуются: на общем плане они превращаются
## в кашу из цифр поверх карты.
const MAX_VISIBLE_CELLS: int = 40

const BAR_WIDTH: float = 30.0
const BAR_HEIGHT: float = 4.0
const FONT_SIZE: int = 9

var registry: BuildingRegistry = null
var simulation: Simulation = null
## Показывать ли шкалы вообще: переключается в настройках.
var enabled: bool = true

var _visible_cells := Rect2i(0, 0, 0, 0)
var _timer: float = 0.0


func _ready() -> void:
	z_index = 4


func setup(building_registry: BuildingRegistry, game_simulation: Simulation) -> void:
	registry = building_registry
	simulation = game_simulation


func set_view(visible_cells: Rect2i) -> void:
	if visible_cells == _visible_cells:
		return
	_visible_cells = visible_cells
	queue_redraw()


func _process(delta: float) -> void:
	_timer += delta
	if _timer < REFRESH_INTERVAL:
		return
	_timer = 0.0
	queue_redraw()


## Здания, у которых есть что показать на шкале.
static func is_gauged(def_id: StringName) -> bool:
	return (
		BuildingDefs.power_gen(def_id) > 0.0
		or BuildingDefs.kind(def_id) == BuildingDefs.Kind.ACCUMULATOR
	)


func _draw() -> void:
	if registry == null or not enabled:
		return
	if _visible_cells.size.x > MAX_VISIBLE_CELLS:
		return

	var font: Font = ThemeDB.fallback_font
	var daylight: float = 1.0 if simulation == null else simulation.daylight()
	for building: Building in registry.in_rect(_visible_cells):
		if not is_gauged(building.def_id):
			continue
		_draw_gauge(font, building, daylight)


func _draw_gauge(font: Font, building: Building, daylight: float) -> void:
	var accumulator: Accumulator = building as Accumulator
	var is_store: bool = accumulator != null
	var ratio: float = 0.0
	var caption: String = ""

	if is_store:
		ratio = accumulator.charge_ratio()
		caption = "%d%%" % int(round(ratio * 100.0))
	else:
		var nominal: float = BuildingDefs.power_gen(building.def_id)
		var actual: float = building.power_supply(daylight)
		ratio = 0.0 if nominal <= 0.0 else clampf(actual / nominal, 0.0, 1.0)
		caption = "%d кВт" % int(round(actual))

	# Шкала висит над зданием, по центру его площади.
	var origin: Vector2 = Grid.cell_to_world(building.origin)
	var width: float = float(building.size.x * Constants.TILE_SIZE)
	var bar_left: float = origin.x + (width - BAR_WIDTH) * 0.5
	var bar_top: float = origin.y - BAR_HEIGHT - 9.0

	draw_rect(Rect2(bar_left - 1.0, bar_top - 1.0, BAR_WIDTH + 2.0, BAR_HEIGHT + 2.0), Palette.OUTLINE)
	draw_rect(Rect2(bar_left, bar_top, BAR_WIDTH, BAR_HEIGHT), Palette.UI_BG)
	if ratio > 0.0:
		var fill: Color = Palette.ENERGY if not is_store else Palette.OK
		draw_rect(Rect2(bar_left, bar_top, BAR_WIDTH * ratio, BAR_HEIGHT), fill)

	# Тень под текстом: белые цифры на светлой траве иначе не читаются.
	var text_size: Vector2 = font.get_string_size(
		caption, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE
	)
	var text_position := Vector2(
		origin.x + (width - text_size.x) * 0.5, bar_top - 2.0
	)
	draw_string(
		font, text_position + Vector2.ONE, caption,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE, Palette.OUTLINE
	)
	draw_string(
		font, text_position, caption,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE, Palette.UI_TEXT
	)
