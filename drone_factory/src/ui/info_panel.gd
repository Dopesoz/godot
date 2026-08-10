class_name InfoPanel
extends UiPanel

## Панель выбранного здания: состояние, содержимое, рецепт, очередь, снос.
##
## Панель открывается тапом по зданию и показывает ровно то, что нужно для
## решения «работает или нет, и что с этим делать». Всё редактируемое —
## рецепт, очередь, выключатель, снос — собрано здесь, чтобы не искать
## настройки по разным экранам.

## Как часто обновляются цифры, пока панель открыта.
const REFRESH_INTERVAL: float = 0.3

var world: GameWorld = null
var controller: BuildController = null

var _building_id: int = 0
var _status_label: Label = null
var _health_label: Label = null
var _progress: ProgressBar = null
var _details: VBoxContainer = null
var _recipes: VBoxContainer = null
var _queue: VBoxContainer = null
var _power_button: Button = null
var _demolish_button: Button = null
var _attack_button: Button = null
var combat: CombatSystem = null
var _timer: float = 0.0


func setup(
	game_world: GameWorld, build_controller: BuildController,
	combat_system: CombatSystem = null
) -> void:
	world = game_world
	controller = build_controller
	combat = combat_system


func _ready() -> void:
	super()
	Events.selection_changed.connect(_on_selection_changed)
	Events.production_queue_changed.connect(_on_building_event)
	Events.building_removed.connect(_on_building_removed)


func _build_content(container: VBoxContainer) -> void:
	set_title("Здание")

	_status_label = UiWidgets.label("", UiTheme.FONT_SMALL, Palette.UI_TEXT_DIM)
	container.add_child(_status_label)

	_health_label = UiWidgets.label("", UiTheme.FONT_SMALL, Palette.WARN)
	_health_label.name = "HealthLabel"
	_health_label.visible = false
	container.add_child(_health_label)

	_progress = UiWidgets.progress_bar()
	container.add_child(_progress)

	_details = VBoxContainer.new()
	_details.add_theme_constant_override("separation", 0)
	container.add_child(_details)

	_queue = VBoxContainer.new()
	_queue.add_theme_constant_override("separation", UiTheme.PAD_S)
	container.add_child(_queue)

	_recipes = VBoxContainer.new()
	_recipes.add_theme_constant_override("separation", UiTheme.PAD_S)
	container.add_child(_recipes)

	# Кнопки действий — в закреплённой строке: искать «Разобрать» прокруткой
	# после длинного списка рецептов игрок не должен.
	var actions: HBoxContainer = footer()

	_power_button = UiWidgets.text_button("Выключить", UiTheme.TOUCH_MIN * 2)
	_power_button.name = "PowerButton"
	_power_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_power_button.pressed.connect(_on_toggle_enabled)
	actions.add_child(_power_button)

	_demolish_button = UiWidgets.text_button("Разобрать", UiTheme.TOUCH_MIN * 2)
	_demolish_button.name = "DemolishButton"
	_demolish_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_demolish_button.pressed.connect(_on_demolish)
	actions.add_child(_demolish_button)

	# Кнопка атаки живёт в той же строке и появляется только у гнёзд: держать
	# её постоянно значило бы предлагать «атаковать» собственную печь.
	_attack_button = UiWidgets.text_button("Атаковать", UiTheme.TOUCH_MIN * 2)
	_attack_button.name = "AttackButton"
	_attack_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_attack_button.visible = false
	_attack_button.pressed.connect(_on_attack)
	actions.add_child(_attack_button)


func _process(delta: float) -> void:
	if not is_open():
		return
	_timer += delta
	if _timer >= REFRESH_INTERVAL:
		_timer = 0.0
		refresh()


func selected_building() -> Building:
	if world == null or world.buildings == null or _building_id == 0:
		return null
	return world.buildings.get_building(_building_id)


## --- Наполнение ------------------------------------------------------------

func refresh() -> void:
	var building: Building = selected_building()
	if building == null:
		close()
		return

	set_title(building.display_name())
	_status_label.text = _status_line(building)
	_status_label.add_theme_color_override("font_color", _status_color(building))
	_power_button.text = "Включить" if not building.enabled else "Выключить"
	var is_nest: bool = building is Nest
	_attack_button.visible = is_nest
	_power_button.visible = not is_nest
	_demolish_button.disabled = not BuildingDefs.can_demolish(building.def_id)

	_refresh_health(building)
	_refresh_progress(building)
	_refresh_details(building)
	_refresh_queue(building)
	_refresh_recipes(building)


## Прочность показывается только повреждённым: у целого здания эта строка
## была бы шумом, а у погрызенного жуками — самое важное на экране.
func _refresh_health(building: Building) -> void:
	if building.health >= building.max_health():
		_health_label.visible = false
		return
	_health_label.visible = true
	_health_label.text = "Прочность: %d / %d" % [building.health, building.max_health()]
	_health_label.add_theme_color_override(
		"font_color", Palette.BAD if building.health_ratio() < 0.35 else Palette.WARN
	)


static func _status_line(building: Building) -> String:
	var parts: PackedStringArray = PackedStringArray([building.status_text()])
	var demand: float = BuildingDefs.power_use(building.def_id)
	if demand > 0.0:
		parts.append("%d кВт, питание %d%%" % [int(demand), int(building.power_satisfaction * 100.0)])
	return " · ".join(parts)


static func _status_color(building: Building) -> Color:
	match building.status:
		Building.Status.WORKING:
			return Palette.OK
		Building.Status.DISABLED, Building.Status.IDLE:
			return Palette.UI_TEXT_DIM
		_:
			return Palette.WARN


func _refresh_progress(building: Building) -> void:
	if building is ProductionBuilding:
		_progress.visible = true
		_progress.value = (building as ProductionBuilding).progress
	elif building is Accumulator:
		_progress.visible = true
		_progress.value = (building as Accumulator).charge_ratio()
	else:
		_progress.visible = false


func _refresh_details(building: Building) -> void:
	UiWidgets.clear_children(_details)

	# Описание здания читается прямо в панели, а не только в меню строительства:
	# через полчаса игры игрок уже не помнит, зачем ставил эту коробку.
	var description: String = BuildingDefs.description(building.def_id)
	if not description.is_empty():
		_details.add_child(UiWidgets.paragraph(description, UiTheme.FONT_SMALL, Palette.UI_TEXT_DIM))

	if building is Drill:
		var drill: Drill = building
		_details.add_child(UiWidgets.label(
			"Руда: %s" % TileTypes.ore_name(drill.ore_type), UiTheme.FONT_SMALL
		))
		_details.add_child(UiWidgets.label(
			"Осталось в земле: %s" % UiWidgets.short_number(drill.remaining_ore(world.grid)),
			UiTheme.FONT_SMALL, Palette.UI_TEXT_DIM
		))
	elif building is DronePort:
		var port: DronePort = building
		_details.add_child(UiWidgets.label(port.courier_caption(), UiTheme.FONT_SMALL))
		_details.add_child(UiWidgets.label(
			"Радиус: %d клеток" % int(port.service_radius()), UiTheme.FONT_SMALL, Palette.UI_TEXT_DIM
		))
	elif building is Accumulator:
		var accumulator: Accumulator = building
		_details.add_child(UiWidgets.label(
			"Заряд: %d%%" % int(accumulator.charge_ratio() * 100.0), UiTheme.FONT_SMALL
		))
	elif building is TankDepot:
		var depot: TankDepot = building
		_details.add_child(UiWidgets.label(
			"Танков: %d из %d" % [depot.tank_count(), TankDepot.MAX_TANKS], UiTheme.FONT_SMALL
		))
		_details.add_child(UiWidgets.label(
			"Свободно: %d" % depot.idle_tanks().size(), UiTheme.FONT_SMALL, Palette.UI_TEXT_DIM
		))
	elif building is Nest:
		var nest: Nest = building
		_details.add_child(UiWidgets.label(
			"Нужно танков одновременно: %d" % nest.required_tanks(),
			UiTheme.FONT_NORMAL, Palette.WARN
		))
		_details.add_child(UiWidgets.paragraph(
			"Гнездо нельзя разобрать. Отправьте колонну из ангара: приедет "
			+ "меньше — техника только погибнет.",
			UiTheme.FONT_SMALL, Palette.UI_TEXT_DIM
		))

	_add_inventory(building.input, "Приём")
	_add_inventory(building.output, "Выдача")


func _add_inventory(inventory: Inventory, caption: String) -> void:
	if inventory == null or inventory.capacity <= 0:
		return
	_details.add_child(UiWidgets.label(
		"%s (%d/%d)" % [caption, inventory.total(), inventory.capacity],
		UiTheme.FONT_SMALL, Palette.UI_TEXT_DIM
	))
	if inventory.is_empty():
		_details.add_child(UiWidgets.label("— пусто —", UiTheme.FONT_SMALL, Palette.UI_TEXT_DIM))
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTheme.PAD_M)
	for item_id: StringName in inventory.item_ids():
		row.add_child(UiWidgets.item_button(
			item_id, str(inventory.count(item_id)),
			func(id: StringName) -> void: Events.item_inspected.emit(id)
		))
	_details.add_child(row)


func _refresh_queue(building: Building) -> void:
	UiWidgets.clear_children(_queue)
	if not (building is ProductionBuilding):
		return
	var machine: ProductionBuilding = building
	if machine.queue.is_empty():
		return

	_queue.add_child(UiWidgets.label("Очередь", UiTheme.FONT_SMALL, Palette.UI_TEXT_DIM))
	for index: int in machine.queue.size():
		var job: Dictionary = machine.queue[index]
		var count: int = int(job["count"])
		var suffix: String = "∞" if count == ProductionBuilding.REPEAT else str(count)
		var button: Button = UiWidgets.text_button(
			"%s × %s   ✕" % [Recipes.display_name(job["recipe"]), suffix]
		)
		button.name = "Job%d" % index
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Тап по заданию убирает его: отдельная крестик-кнопка была бы слишком
		# мелкой целью на телефоне.
		button.pressed.connect(_on_remove_job.bind(index))
		_queue.add_child(button)


func _refresh_recipes(building: Building) -> void:
	UiWidgets.clear_children(_recipes)
	if not (building is ProductionBuilding):
		return
	var machine: ProductionBuilding = building
	var available: Array[StringName] = world.research.unlocked_recipes(machine.machine_kind())
	if available.is_empty():
		return

	_recipes.add_child(UiWidgets.label("Рецепты", UiTheme.FONT_SMALL, Palette.UI_TEXT_DIM))
	for recipe_id: StringName in available:
		_recipes.add_child(_recipe_row(machine, recipe_id))


func _recipe_row(machine: ProductionBuilding, recipe_id: StringName) -> Control:
	var button := Button.new()
	button.name = String(recipe_id)
	button.custom_minimum_size = Vector2(0, UiTheme.TOUCH_MIN)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(_on_pick_recipe.bind(recipe_id))

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", UiTheme.PAD_M)
	button.add_child(row)

	var product: StringName = &""
	for item_id: StringName in Recipes.outputs(recipe_id):
		product = item_id
		break

	var icon := TextureRect.new()
	icon.texture = Art.icon(product)
	icon.custom_minimum_size = Vector2(32, 32)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var is_current: bool = machine.current_recipe() == recipe_id
	var label: Label = UiWidgets.label(
		Recipes.display_name(recipe_id), UiTheme.FONT_SMALL,
		Palette.ACCENT if is_current else Palette.UI_TEXT
	)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)

	var inputs: PackedStringArray = PackedStringArray()
	for item_id: StringName in Recipes.inputs(recipe_id):
		inputs.append("%s %d" % [Items.display_name(item_id), int(Recipes.inputs(recipe_id)[item_id])])
	var detail: Label = UiWidgets.label(", ".join(inputs), UiTheme.FONT_SMALL, Palette.UI_TEXT_DIM)
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(detail)
	return button


## --- Действия --------------------------------------------------------------

func _on_pick_recipe(recipe_id: StringName) -> void:
	var machine: ProductionBuilding = selected_building() as ProductionBuilding
	if machine == null:
		return
	machine.set_recipe(recipe_id)
	Events.notify.emit("Рецепт: %s" % Recipes.display_name(recipe_id))
	refresh()


func _on_remove_job(index: int) -> void:
	var machine: ProductionBuilding = selected_building() as ProductionBuilding
	if machine != null:
		machine.remove_job(index)
		refresh()


func _on_toggle_enabled() -> void:
	var building: Building = selected_building()
	if building == null:
		return
	building.enabled = not building.enabled
	Events.building_state_changed.emit(building.id)
	refresh()


## Приказ колонне. Панель не закрывается: игрок должен увидеть сообщение
## о том, сколько танков выехало и хватает ли их.
func _on_attack() -> void:
	var nest: Nest = selected_building() as Nest
	if nest == null or combat == null:
		return
	combat.order_attack(world.buildings, nest.id)


func _on_demolish() -> void:
	var building: Building = selected_building()
	if building == null or controller == null:
		return
	controller.demolish(building.id)
	close()


## --- События ---------------------------------------------------------------

func _on_selection_changed(building_id: int) -> void:
	_building_id = maxi(building_id, 0)
	if _building_id == 0:
		close()
		return
	open()
	refresh()


func _on_building_event(building_id: int) -> void:
	if building_id == _building_id and is_open():
		refresh()


func _on_building_removed(building_id: int) -> void:
	if building_id == _building_id:
		_building_id = 0
		close()


func close() -> void:
	super()
	# Снимаем выделение: иначе повторный тап по тому же зданию не откроет
	# панель, потому что выбор формально не менялся.
	if controller != null and controller.selected_id != 0:
		controller.select(0)
