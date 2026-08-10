class_name UiWidgets
extends RefCounted

## Предельная ширина содержимого панели в единицах базового разрешения.
##
## Заметно больше базовых 720: при растяжении «expand» видимая ширина у обычных
## телефонов получается 720-820 единиц, и предел не должен срабатывать на них.
## Ограничение существует ради планшетов, где кнопка во всю ширину выглядит
## нелепо, а её центр с текстом уезжает далеко от пальца.
const MAX_CONTENT_WIDTH: int = 900

## Фабрика типовых элементов интерфейса.
##
## Собирать панели из кода, а не из .tscn, здесь выгоднее: элементы
## однотипные, их десятки, и любое изменение размеров под палец должно
## применяться разом ко всем.


## Кнопка с иконкой предмета или здания и подписью снизу.
static func icon_button(
	sprite_key: StringName, caption: String, minimum_width: int = UiTheme.TOUCH_LARGE
) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(minimum_width, UiTheme.TOUCH_LARGE)
	button.focus_mode = Control.FOCUS_NONE
	button.clip_text = true

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 0)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	button.add_child(box)

	var icon := TextureRect.new()
	icon.texture = Art.icon(sprite_key)
	icon.custom_minimum_size = Vector2(32, 32)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)

	var label := Label.new()
	label.text = caption
	label.add_theme_font_size_override("font_size", UiTheme.FONT_SMALL)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)
	return button


## Обычная текстовая кнопка нужного под палец размера.
static func text_button(text: String, minimum_width: int = UiTheme.TOUCH_MIN * 2) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(minimum_width, UiTheme.TOUCH_MIN)
	button.focus_mode = Control.FOCUS_NONE
	return button


## Строка «иконка + число»: показатель ресурса в верхней панели.
static func stat_row(sprite_key: StringName, value: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTheme.PAD_S)

	var icon := TextureRect.new()
	icon.texture = Art.icon(sprite_key)
	icon.custom_minimum_size = Vector2(28, 28)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.name = "Icon"
	row.add_child(icon)

	var label := Label.new()
	label.text = value
	label.name = "Value"
	label.add_theme_font_size_override("font_size", UiTheme.FONT_SMALL)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	return row


## Строка показателя, по которой можно тапнуть, чтобы открыть справку.
##
## Кнопка-обёртка, а не обработчик на самой строке: тап должен ловиться по
## всей площади вместе с иконкой и цифрой, а на телефоне мелкая цель — это
## промах. Внутри — тот же stat_row, поэтому вид не расходится.
static func item_button(item_id: StringName, value: String, action: Callable) -> Button:
	var button := Button.new()
	button.name = String(item_id)
	button.focus_mode = Control.FOCUS_NONE
	button.flat = true
	button.custom_minimum_size = Vector2(0, UiTheme.TOUCH_MIN * 0.6)
	button.pressed.connect(func() -> void: action.call(item_id))

	var row: HBoxContainer = stat_row(item_id, value)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in row.get_children():
		(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(row)
	return button


static func label(text: String, size: int = UiTheme.FONT_NORMAL, color: Color = Palette.UI_TEXT) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	return node


static func title(text: String) -> Label:
	return label(text, UiTheme.FONT_LARGE)


## Многострочный текст: описание, подсказка, кусок сюжета.
##
## Отдельная фабрика, а не флаг у label(), потому что перенос меняет поведение
## в раскладке: у обычной подписи минимальная ширина равна всей строке, и такая
## подпись раздвигает панель за край экрана. У переносимой минимум — самое
## длинное слово, поэтому она честно ужимается под любой экран.
static func paragraph(
	text: String, size: int = UiTheme.FONT_SMALL, color: Color = Palette.UI_TEXT
) -> Label:
	var node: Label = label(text, size, color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.custom_minimum_size = Vector2(0, 0)
	return node


static func separator() -> HSeparator:
	var line := HSeparator.new()
	line.add_theme_constant_override("separation", UiTheme.PAD_S)
	return line


## Панель с фоном и вертикальной раскладкой внутри.
static func panel(children_separation: int = UiTheme.PAD_S) -> PanelContainer:
	var container := PanelContainer.new()
	var box := VBoxContainer.new()
	box.name = "Content"
	box.add_theme_constant_override("separation", children_separation)
	container.add_child(box)
	return container


## Содержимое панели, созданной panel().
static func panel_content(container: PanelContainer) -> VBoxContainer:
	return container.get_node("Content") as VBoxContainer


static func progress_bar(minimum_height: int = 14) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, minimum_height)
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.show_percentage = false
	return bar


## Жёстко сажает корневой Control интерфейса на видимую область вьюпорта.
##
## Якоря у Control внутри CanvasLayer вычисляются от вьюпорта, но на Android
## окно получает настоящий размер уже после старта, и корень остаётся с прежними
## габаритами — интерфейс уезжает за край экрана. Поэтому размер выставляется
## явно, а владелец интерфейса вызывает это ещё раз на каждый size_changed.
##
## Подписку сознательно оставляем вызывающему: сигнал нужно связывать с методом
## самого узла, чтобы движок снял связь при удалении. Лямбда так не умеет — её
## захват переживает узел и валится ошибкой на каждом изменении размера.
static func fit_to_viewport(root: Control) -> void:
	var viewport: Viewport = root.get_viewport()
	if viewport == null:
		return
	# Штатный путь: якоря на всю площадь. Для Control внутри CanvasLayer
	# «родительская площадь» — это и есть видимая область вьюпорта, и движок
	# сам пересчитает её при любом изменении размера окна.
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Страховка: если родительская область почему-то ещё старая (на Android
	# сигнал о размере приходит раньше, чем вьюпорт пересчитает растяжение),
	# дотягиваем размер руками. Следующий вызов вернёт честные якоря.
	var visible: Vector2 = viewport.get_visible_rect().size
	if not root.size.is_equal_approx(visible):
		root.position = Vector2.ZERO
		root.size = visible


static func clear_children(node: Node) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()


## Короткая запись числа: 1240 -> «1.2к». Место в верхней панели дорого.
static func short_number(value: int) -> String:
	if value < 1000:
		return str(value)
	if value < 1000000:
		return "%.1fк" % (float(value) / 1000.0)
	return "%.1fм" % (float(value) / 1000000.0)
