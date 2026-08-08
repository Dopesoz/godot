class_name UiPanel
extends UiLayer

## Базовая всплывающая панель — «нижний лист».
##
## Панели выезжают снизу и занимают нижнюю часть экрана: верх остаётся видимым
## (там карта и показатели), а всё содержимое попадает в зону большого пальца.
## Затемнение сверху одновременно гасит фон и ловит касание «мимо панели»,
## закрывая лист, — привычный на Android жест.
##
## Содержимое всегда лежит внутри прокрутки, и это не украшение, а защита.
## Control в Godot не может стать уже своего минимального размера: одна длинная
## строка без переносов внутри листа раздвигала бы весь лист за край экрана —
## именно так интерфейс и «растягивался» на телефоне. У прокрутки с отключённым
## показом горизонтальной полосы минимум по ширине не передаётся наружу, поэтому
## лист физически не может вылезти за экран, что бы в него ни положили.

signal opened()
signal closed()

## Какую долю высоты экрана занимает лист.
const HEIGHT_RATIO: float = 0.62

var title_text: String = "Панель"

var _dim: ColorRect = null
var _holder: MarginContainer = null
var _panel: PanelContainer = null
var _scroll: ScrollContainer = null
var _content: VBoxContainer = null
var _footer: HBoxContainer = null
var _is_open: bool = false


func _ready() -> void:
	layer = 20
	_build()
	visible = false


func _build() -> void:
	var root := Control.new()
	root.name = "Root"
	root.theme = UiTheme.shared()
	add_child(root)

	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.45)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.gui_input.connect(_on_dim_input)
	root.add_child(_dim)

	var holder := MarginContainer.new()
	_holder = holder
	holder.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	holder.anchor_top = 1.0 - HEIGHT_RATIO
	holder.anchor_bottom = 1.0
	holder.offset_top = 0
	holder.offset_bottom = 0
	root.add_child(holder)
	attach_root(root)

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

	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Вертикально — обычная прокрутка. Горизонтально — «никогда не показывать»:
	# полосы нет, но и минимум по ширине наружу не уходит, а значит лист не
	# растянется. SCROLL_MODE_DISABLED так не умеет — он как раз пробрасывает
	# минимум родителю.
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	column.add_child(_scroll)

	_content = VBoxContainer.new()
	_content.name = "Content"
	# EXPAND по обеим осям: прокрутка растягивает такого ребёнка до своей
	# ширины, вместо того чтобы оставить его в минимальном размере.
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", UiTheme.PAD_S)
	_scroll.add_child(_content)

	# Нижняя строка действий остаётся на месте при прокрутке: кнопки вроде
	# «Разобрать» нельзя прятать за скроллом.
	_footer = HBoxContainer.new()
	_footer.name = "Footer"
	_footer.visible = false
	_footer.add_theme_constant_override("separation", UiTheme.PAD_M)
	column.add_child(_footer)

	_build_content(_content)


func _fit_layout() -> void:
	_fit_content_width()


## Ширина содержимого ограничена: на широком экране кнопка во всю ширину
## выглядит нелепо, а её центр с текстом уезжает далеко от пальца. Отступы
## пересчитываются при каждой смене размера окна.
func _fit_content_width() -> void:
	if _holder == null:
		return
	var margins: Vector4i = UiTheme.safe_area_margins()
	var available: float = get_viewport().get_visible_rect().size.x
	var extra: int = maxi(int(available) - UiWidgets.MAX_CONTENT_WIDTH, 0) / 2
	_holder.add_theme_constant_override("margin_left", margins.x + extra)
	_holder.add_theme_constant_override("margin_right", margins.z + extra)
	_holder.add_theme_constant_override("margin_bottom", margins.w)


## Точка расширения: наследник наполняет лист.
func _build_content(_container: VBoxContainer) -> void:
	pass


## Вызывается при каждом открытии — данные к этому моменту могли измениться.
func _on_open() -> void:
	pass


func content() -> VBoxContainer:
	return _content


## Строка кнопок под прокруткой. Появляется, как только в неё что-то положили.
func footer() -> HBoxContainer:
	_footer.visible = true
	return _footer


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
