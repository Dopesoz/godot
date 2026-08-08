class_name ResearchPanel
extends UiPanel

## Панель исследований: что изучается сейчас и что можно выбрать дальше.
##
## Технологии показаны одним списком, разделённым на «доступные», «закрытые»
## и «изученные». Дерево со связями красиво на большом экране, но на телефоне
## его невозможно ни рассмотреть, ни удобно листать.

var research: ResearchSystem = null
var state: ResearchState = null

var _current_label: Label = null
var _progress: ProgressBar = null
var _cost_label: Label = null
var _list: VBoxContainer = null
var _cancel_button: Button = null
var _trade_box: HBoxContainer = null


func setup(research_system: ResearchSystem, research_state: ResearchState) -> void:
	research = research_system
	state = research_state


func _ready() -> void:
	super()
	Events.research_progress_changed.connect(_on_progress_changed)
	Events.research_completed.connect(_on_completed)


func _build_content(container: VBoxContainer) -> void:
	set_title("Исследования")

	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 0)
	container.add_child(header)

	_current_label = UiWidgets.label("Ничего не изучается", UiTheme.FONT_NORMAL)
	header.add_child(_current_label)

	_cost_label = UiWidgets.label("", UiTheme.FONT_SMALL, Palette.UI_TEXT_DIM)
	header.add_child(_cost_label)

	_progress = UiWidgets.progress_bar(18)
	container.add_child(_progress)

	_cancel_button = UiWidgets.text_button("Отменить исследование", UiTheme.TOUCH_MIN * 4)
	_cancel_button.name = "CancelButton"
	_cancel_button.pressed.connect(_on_cancel)
	container.add_child(_cancel_button)

	_trade_box = HBoxContainer.new()
	_trade_box.add_theme_constant_override("separation", UiTheme.PAD_S)
	container.add_child(_trade_box)

	_list = VBoxContainer.new()
	_list.name = "List"
	_list.add_theme_constant_override("separation", UiTheme.PAD_S)
	container.add_child(_list)


func _on_open() -> void:
	refresh()


func refresh() -> void:
	if _list == null or state == null:
		return
	_refresh_header()

	_refresh_trade()

	UiWidgets.clear_children(_list)
	var available: Array[StringName] = []
	var locked: Array[StringName] = []
	var done: Array[StringName] = []
	for tech_id: StringName in Technologies.all_ids():
		if state.is_completed(tech_id):
			done.append(tech_id)
		elif state.is_available(tech_id):
			available.append(tech_id)
		else:
			locked.append(tech_id)

	_add_section("Доступно", available)
	_add_section("Требует предшественников", locked)
	_add_section("Изучено", done)


func _refresh_header() -> void:
	var active: StringName = &"" if research == null else research.current
	_cancel_button.visible = active != &""
	if active == &"":
		_current_label.text = "Ничего не изучается"
		_cost_label.text = "Выберите технологию из списка"
		_progress.value = 0.0
		return

	_current_label.text = Technologies.display_name(active)
	_progress.value = research.progress()
	var parts: PackedStringArray = PackedStringArray()
	for item_id: StringName in research.remaining_cost():
		parts.append("%s %d" % [Items.display_name(item_id), int(research.remaining_cost()[item_id])])
	_cost_label.text = "Осталось: " + ", ".join(parts) if not parts.is_empty() else "Почти готово"


## Кнопки обмена находок с метеоритов. Показываются только когда обмен
## действительно возможен: пустая кнопка «нельзя» только раздражает.
func _refresh_trade() -> void:
	if _trade_box == null or research == null:
		return
	UiWidgets.clear_children(_trade_box)
	for item_id: StringName in ResearchSystem.TRADE_RATES:
		if not research.can_trade(item_id):
			continue
		var button: Button = UiWidgets.text_button("%s %d → +%d" % [
			Items.display_name(item_id),
			research.trade_cost(item_id),
			research.trade_gain(item_id),
		], UiTheme.TOUCH_MIN * 3)
		button.name = "Trade_" + String(item_id)
		button.pressed.connect(func() -> void:
			research.trade(item_id)
			refresh()
		)
		_trade_box.add_child(button)


func _add_section(caption: String, techs: Array[StringName]) -> void:
	if techs.is_empty():
		return
	_list.add_child(UiWidgets.label(caption, UiTheme.FONT_SMALL, Palette.UI_TEXT_DIM))
	for tech_id: StringName in techs:
		_list.add_child(_build_row(tech_id))


func _build_row(tech_id: StringName) -> Control:
	var completed: bool = state.is_completed(tech_id)
	var available: bool = state.is_available(tech_id)

	var button := Button.new()
	button.name = String(tech_id)
	button.custom_minimum_size = Vector2(0, UiTheme.TOUCH_LARGE)
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = not available
	if available:
		button.pressed.connect(_on_start.bind(tech_id))

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 0)
	button.add_child(box)

	var name_color: Color = Palette.OK if completed else Palette.UI_TEXT
	var name_label: Label = UiWidgets.label(Technologies.display_name(tech_id), UiTheme.FONT_NORMAL, name_color)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_label)

	var detail: String = Technologies.description(tech_id)
	if completed:
		detail = "Изучено · " + detail
	elif not available:
		var missing: PackedStringArray = PackedStringArray()
		for requirement: Variant in Technologies.requires(tech_id):
			if not state.is_completed(requirement):
				missing.append(Technologies.display_name(requirement))
		detail = "Сначала: " + ", ".join(missing)
	else:
		detail = _cost_text(tech_id) + " · " + detail
	var detail_label: Label = UiWidgets.label(detail, UiTheme.FONT_SMALL, Palette.UI_TEXT_DIM)
	detail_label.name = "Detail"
	detail_label.clip_text = true
	detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(detail_label)
	return button


static func _cost_text(tech_id: StringName) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for item_id: StringName in Technologies.cost(tech_id):
		parts.append("%s %d" % [Items.display_name(item_id), int(Technologies.cost(tech_id)[item_id])])
	return ", ".join(parts)


func _on_start(tech_id: StringName) -> void:
	if research == null or not research.start(tech_id):
		return
	Events.notify.emit("Изучаем: %s" % Technologies.display_name(tech_id))
	refresh()


func _on_cancel() -> void:
	if research != null:
		research.cancel()
		refresh()


func _on_progress_changed(_tech_id: StringName, _progress_value: float) -> void:
	if is_open():
		_refresh_header()


func _on_completed(_tech_id: StringName) -> void:
	if is_open():
		refresh()
