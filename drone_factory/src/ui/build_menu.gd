class_name BuildMenu
extends UiPanel

## Меню строительства: список зданий с ценой и требуемой технологией.
##
## Список прокручиваемый и одноколоночный: на узком экране плитки в две-три
## колонки становятся мельче цели касания, а цену на них уже не подписать.

var controller: BuildController = null
var pool: ResourcePool = null
var research: ResearchState = null

var _list: VBoxContainer = null


func setup(build_controller: BuildController, research_state: ResearchState) -> void:
	controller = build_controller
	pool = build_controller.pool
	research = research_state


func _build_content(container: VBoxContainer) -> void:
	set_title("Строительство")
	var scroll: ScrollContainer = UiWidgets.scroll_list()
	container.add_child(scroll)
	_list = UiWidgets.scroll_list_content(scroll)


func _on_open() -> void:
	refresh()


func refresh() -> void:
	if _list == null or controller == null:
		return
	UiWidgets.clear_children(_list)
	for def_id: StringName in BuildingDefs.BUILD_ORDER:
		if BuildingDefs.is_player_built(def_id):
			_list.add_child(_build_row(def_id))


func _build_row(def_id: StringName) -> Control:
	var unlocked: bool = research == null or research.is_building_unlocked(def_id)
	var affordable: bool = pool != null and pool.has_all(BuildingDefs.cost(def_id))

	var button := Button.new()
	button.name = String(def_id)
	button.custom_minimum_size = Vector2(0, UiTheme.TOUCH_LARGE)
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = not unlocked
	button.pressed.connect(_on_row_pressed.bind(def_id))

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", UiTheme.PAD_M)
	button.add_child(row)

	var icon := TextureRect.new()
	icon.texture = Art.icon(def_id)
	icon.custom_minimum_size = Vector2(48, 48)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_constant_override("separation", 0)
	row.add_child(text)

	var name_label: Label = UiWidgets.label(BuildingDefs.display_name(def_id), UiTheme.FONT_NORMAL)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(name_label)

	var detail: String = _cost_text(def_id)
	var detail_color: Color = Palette.UI_TEXT_DIM
	if not unlocked:
		detail = "Нужно: %s" % Technologies.display_name(BuildingDefs.required_tech(def_id))
		detail_color = Palette.WARN
	elif not affordable:
		# Не хватает ресурсов — кнопка остаётся нажимаемой: игрок может
		# выбрать здание заранее и построить, когда дроны подвезут материалы.
		detail_color = Palette.BAD
	var detail_label: Label = UiWidgets.label(detail, UiTheme.FONT_SMALL, detail_color)
	detail_label.name = "Detail"
	detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(detail_label)
	return button


static func _cost_text(def_id: StringName) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for item_id: StringName in BuildingDefs.cost(def_id):
		parts.append("%s %d" % [Items.display_name(item_id), int(BuildingDefs.cost(def_id)[item_id])])
	return ", ".join(parts)


func _on_row_pressed(def_id: StringName) -> void:
	controller.start_building(def_id)
	close()
