class_name UiPanel
extends CanvasLayer

## Базовая всплывающая панель — «нижний лист».
##
## Панели выезжают снизу и занимают нижнюю часть экрана: верх остаётся видимым
## (там карта и показатели), а всё содержимое попадает в зону большого пальца.
## Затемнение сверху одновременно гасит фон и ловит касание «мимо панели»,
## закрывая лист, — привычный на Android жест.

signal opened()
signal closed()

## Какую долю высоты экрана занимает лист.
const HEIGHT_RATIO: float = 0.62

var title_text: String = "Панель"

var _dim: ColorRect = null
var _panel: PanelContainer = null
var _content: VBoxContainer = null
var _is_open: bool = false


func _ready() -> void:
	layer = 20
	_build()
	visible = false


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UiTheme.shared()
	add_child(root)

	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.45)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.gui_input.connect(_on_dim_input)
	root.add_child(_dim)

	var margins: Vector4i = UiTheme.safe_area_margins()
	var holder := MarginContainer.new()
	holder.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	holder.anchor_top = 1.0 - HEIGHT_RATIO
	holder.anchor_bottom = 1.0
	holder.offset_top = 0
	holder.offset_bottom = 0
	holder.add_theme_constant_override("margin_left", margins.x)
	holder.add_theme_constant_override("margin_right", margins.z)
	holder.add_theme_constant_override("margin_bottom", margins.w)
	root.add_child(holder)

	_panel = PanelContainer.new()
	holder.add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", UiTheme.PAD_S)
	_panel.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", UiTheme.PAD_M)
	column.add_child(header)

	var title: Label = UiWidgets.title(title_text)
	title.name = "Title"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_button: Button = UiWidgets.text_button("Закрыть", UiTheme.TOUCH_MIN * 2)
	close_button.name = "CloseButton"
	close_button.pressed.connect(close)
	header.add_child(close_button)

	column.add_child(UiWidgets.separator())

	_content = VBoxContainer.new()
	_content.name = "Content"
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", UiTheme.PAD_S)
	column.add_child(_content)

	_build_content(_content)


## Точка расширения: наследник наполняет лист.
func _build_content(_container: VBoxContainer) -> void:
	pass


## Вызывается при каждом открытии — данные к этому моменту могли измениться.
func _on_open() -> void:
	pass


func content() -> VBoxContainer:
	return _content


func set_title(text: String) -> void:
	title_text = text
	var title: Label = find_child("Title", true, false) as Label
	if title != null:
		title.text = text


func open() -> void:
	if _is_open:
		return
	_is_open = true
	visible = true
	_on_open()
	opened.emit()


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	visible = false
	closed.emit()


func toggle() -> void:
	if _is_open:
		close()
	else:
		open()


func is_open() -> bool:
	return _is_open


func _on_dim_input(event: InputEvent) -> void:
	# Касание мимо панели закрывает её — на телефоне это ожидаемое поведение.
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		close()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		close()
