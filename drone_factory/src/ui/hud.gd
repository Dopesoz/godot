class_name Hud
extends UiLayer

## Основной интерфейс поверх карты.
##
## Раскладка рассчитана на одну руку: показатели сверху (их только читают),
## все кнопки — внизу, в зоне большого пальца. Середина экрана свободна,
## потому что именно там игрок строит.
##
## Обновление идёт по событиям и с ограничением частоты: пересобирать строки
## показателей десять раз в секунду — впустую сжигать батарею.

## Как часто пересчитываются суммы по складам, секунды.
const STATS_REFRESH_INTERVAL: float = 0.5
## Сколько держится всплывающее сообщение.
const TOAST_TIME: float = 2.2

## Игрок просит вернуть камеру к базе.
signal home_requested()
signal build_menu_requested()
## Игрок тапнул по строке задачи.
signal story_requested()
signal research_requested()
signal menu_requested()

var world: GameWorld = null
var simulation: Simulation = null
var pool: ResourcePool = null
var story: StorySystem = null

var show_fps: bool = OS.is_debug_build()

var _top_bar: PanelContainer = null
var _stats_box: HBoxContainer = null
var _power_label: Label = null
var _drones_label: Label = null
var _time_label: Label = null
var _pollution_label: Label = null
var _objective_button: Button = null
var _fps_label: Label = null
var _toast: Label = null
var _bottom_bar: HBoxContainer = null

var _stats_timer: float = 0.0
var _toast_timer: float = 0.0
var _stats_dirty: bool = true
## Какие ресурсы показывать в верхней панели: место ограничено, поэтому
## только ключевые для текущего этапа игры.
var _tracked_items: Array[StringName] = [
	Items.IRON_PLATE, Items.COPPER_PLATE, Items.STONE, Items.CIRCUIT,
]


func _ready() -> void:
	layer = 10
	_build_layout()

	Events.inventory_changed.connect(_on_inventory_changed)
	Events.power_stats_changed.connect(_on_power_changed)
	Events.drone_count_changed.connect(_on_drones_changed)
	Events.pollution_changed.connect(_on_pollution_changed)
	Events.story_advanced.connect(func(_a: StringName, _b: StringName) -> void: refresh_objective())
	Events.notify.connect(show_toast)
	Events.unlocks_changed.connect(func() -> void: _stats_dirty = true)


func setup(game_world: GameWorld, game_simulation: Simulation) -> void:
	world = game_world
	simulation = game_simulation
	pool = ResourcePool.new(game_world.buildings)
	story = game_simulation.get_system(StorySystem) as StorySystem
	_stats_dirty = true
	refresh_objective()


func _process(delta: float) -> void:
	_stats_timer += delta
	if _stats_dirty and _stats_timer >= STATS_REFRESH_INTERVAL:
		_stats_timer = 0.0
		_stats_dirty = false
		_refresh_stats()
		refresh_objective()

	if simulation != null and _time_label != null:
		_time_label.text = simulation.time_of_day_text()

	if _fps_label != null:
		_fps_label.visible = show_fps
		if show_fps:
			_fps_label.text = "%d FPS" % Engine.get_frames_per_second()

	if _toast_timer > 0.0:
		_toast_timer -= delta
		_toast.modulate.a = clampf(_toast_timer / 0.4, 0.0, 1.0)
		if _toast_timer <= 0.0:
			_toast.visible = false


## --- Раскладка -------------------------------------------------------------

func _build_layout() -> void:
	var root := MarginContainer.new()
	root.name = "Root"
	# Отступы под безопасную зону выставит _fit_layout(): до того, как окно
	# получило настоящий размер, они всё равно неизвестны.
	# Пустое место интерфейса должно пропускать касания к карте.
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.shared()
	add_child(root)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", UiTheme.PAD_S)
	root.add_child(column)

	column.add_child(_build_top_bar())
	column.add_child(_build_objective())

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)

	column.add_child(_build_map_controls())
	column.add_child(_build_toast())
	column.add_child(_build_bottom_bar())

	attach_root(root)


func _build_top_bar() -> Control:
	_top_bar = UiWidgets.panel()
	var content: VBoxContainer = UiWidgets.panel_content(_top_bar)

	_stats_box = HBoxContainer.new()
	_stats_box.add_theme_constant_override("separation", UiTheme.PAD_M)
	content.add_child(_stats_box)

	var status := HBoxContainer.new()
	status.add_theme_constant_override("separation", UiTheme.PAD_M)
	content.add_child(status)

	_power_label = UiWidgets.label("0/0 кВт", UiTheme.FONT_SMALL, Palette.ENERGY)
	status.add_child(_power_label)

	_drones_label = UiWidgets.label("Курьеры 0/0", UiTheme.FONT_SMALL, Palette.UI_TEXT_DIM)
	status.add_child(_drones_label)

	_time_label = UiWidgets.label("День", UiTheme.FONT_SMALL, Palette.UI_TEXT_DIM)
	status.add_child(_time_label)

	# Загрязнение появляется в строке только когда оно есть: на чистой карте
	# лишний показатель занимал бы место впустую.
	_pollution_label = UiWidgets.label("", UiTheme.FONT_SMALL, Palette.WARN)
	_pollution_label.visible = false
	status.add_child(_pollution_label)

	var filler := Control.new()
	filler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.add_child(filler)

	_fps_label = UiWidgets.label("", UiTheme.FONT_SMALL, Palette.OK)
	_fps_label.visible = show_fps
	status.add_child(_fps_label)
	return _top_bar


## Строка текущей задачи. Она же обучение: игрок всегда видит следующий шаг,
## не открывая ни одной панели. Тап открывает дневник с полным текстом.
func _build_objective() -> Control:
	_objective_button = Button.new()
	_objective_button.name = "ObjectiveButton"
	_objective_button.custom_minimum_size = Vector2(0, UiTheme.TOUCH_MIN)
	_objective_button.focus_mode = Control.FOCUS_NONE
	_objective_button.clip_text = true
	_objective_button.pressed.connect(func() -> void: story_requested.emit())
	return _objective_button


## Кнопки поверх карты. Пока одна: возврат к базе. На большой карте потеряться
## проще простого, а искать базу вслепую пальцем — худшее, что можно предложить
## игроку на телефоне.
func _build_map_controls() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var home: Button = UiWidgets.text_button("К базе", UiTheme.TOUCH_MIN * 2)
	home.name = "HomeButton"
	home.pressed.connect(func() -> void: home_requested.emit())
	row.add_child(home)
	return row


func _build_toast() -> Control:
	var container := PanelContainer.new()
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_toast = UiWidgets.label("", UiTheme.FONT_SMALL)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(_toast)
	container.visible = false
	_toast.visible = false
	return container


func _build_bottom_bar() -> Control:
	_bottom_bar = HBoxContainer.new()
	_bottom_bar.add_theme_constant_override("separation", UiTheme.PAD_M)
	_bottom_bar.alignment = BoxContainer.ALIGNMENT_CENTER

	var build_button: Button = UiWidgets.text_button("Строить")
	build_button.name = "BuildButton"
	build_button.custom_minimum_size = Vector2(UiTheme.TOUCH_MIN * 3, UiTheme.TOUCH_LARGE)
	build_button.pressed.connect(func() -> void: build_menu_requested.emit())
	_bottom_bar.add_child(build_button)

	var research_button: Button = UiWidgets.text_button("Наука")
	research_button.name = "ResearchButton"
	research_button.custom_minimum_size = Vector2(UiTheme.TOUCH_MIN * 2, UiTheme.TOUCH_LARGE)
	research_button.pressed.connect(func() -> void: research_requested.emit())
	_bottom_bar.add_child(research_button)

	var menu_button: Button = UiWidgets.text_button("Меню")
	menu_button.name = "MenuButton"
	menu_button.custom_minimum_size = Vector2(UiTheme.TOUCH_MIN * 2, UiTheme.TOUCH_LARGE)
	menu_button.pressed.connect(func() -> void: menu_requested.emit())
	_bottom_bar.add_child(menu_button)
	return _bottom_bar


## Безопасная зона тоже известна только после того, как окно получило
## настоящий размер, поэтому отступы пересчитываются вместе с раскладкой.
func _fit_layout() -> void:
	var margins: Vector4i = UiTheme.safe_area_margins()
	_root.add_theme_constant_override("margin_left", margins.x)
	_root.add_theme_constant_override("margin_top", margins.y)
	_root.add_theme_constant_override("margin_right", margins.z)
	_root.add_theme_constant_override("margin_bottom", margins.w)


## --- Обновление ------------------------------------------------------------

func _refresh_stats() -> void:
	if pool == null or _stats_box == null:
		return
	UiWidgets.clear_children(_stats_box)
	var totals: Dictionary[StringName, int] = pool.totals()
	for item_id: StringName in _tracked_items:
		_stats_box.add_child(UiWidgets.stat_row(item_id, UiWidgets.short_number(totals.get(item_id, 0))))


func _on_inventory_changed(_building_id: int) -> void:
	# Событий об инвентаре очень много: помечаем панель устаревшей, а пересчёт
	# делаем не чаще двух раз в секунду.
	_stats_dirty = true


func _on_power_changed(produced: float, consumed: float, satisfaction: float) -> void:
	if _power_label == null:
		return
	_power_label.text = "%d/%d кВт" % [int(produced), int(consumed)]
	# Цвет — самый быстрый способ сообщить о нехватке энергии на маленьком экране.
	if satisfaction >= 0.999 or consumed <= 0.0:
		_power_label.add_theme_color_override("font_color", Palette.ENERGY)
	elif satisfaction > 0.5:
		_power_label.add_theme_color_override("font_color", Palette.WARN)
	else:
		_power_label.add_theme_color_override("font_color", Palette.BAD)


func _on_drones_changed(active: int, total: int) -> void:
	if _drones_label != null:
		_drones_label.text = "Курьеры %d/%d" % [active, total]


## Обновляет строку задачи. Прогресс пересчитывается вместе со сводкой
## по складам, то есть не чаще двух раз в секунду.
func refresh_objective() -> void:
	if _objective_button == null:
		return
	if story == null:
		_objective_button.visible = false
		return
	if story.is_finished():
		_objective_button.text = "✓ Экспедиция завершена"
		return
	var progress: String = story.progress_text()
	_objective_button.text = "Задача: %s%s" % [
		story.hint(), "" if progress.is_empty() else "  (%s)" % progress,
	]


func _on_pollution_changed(level: float, solar_factor: float) -> void:
	if _pollution_label == null:
		return
	_pollution_label.visible = level > 1.0
	if not _pollution_label.visible:
		return
	# Игроку важно не абсолютное число, а насколько копоть съедает солнце.
	_pollution_label.text = "Смог −%d%% солнцу" % int(round((1.0 - solar_factor) * 100.0))
	_pollution_label.add_theme_color_override(
		"font_color", Palette.BAD if solar_factor < 0.75 else Palette.WARN
	)


func show_toast(text: String) -> void:
	if _toast == null:
		return
	_toast.text = text
	_toast.visible = true
	_toast.modulate.a = 1.0
	_toast.get_parent().visible = true
	_toast_timer = TOAST_TIME


func toast_text() -> String:
	return "" if _toast == null else _toast.text


func is_toast_visible() -> bool:
	return _toast != null and _toast.visible
