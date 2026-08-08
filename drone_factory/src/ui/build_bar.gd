class_name BuildBar
extends CanvasLayer

## Панель подтверждения постройки.
##
## Появляется только в режиме строительства и содержит ровно два действия:
## поставить и отменить. Кнопка подтверждения крупная и справа — под правый
## большой палец; причина отказа пишется рядом, чтобы игрок не гадал, почему
## здание не ставится.

var controller: BuildController = null

var _root: Control = null
var _title: Label = null
var _hint: Label = null
var _confirm: Button = null


func _ready() -> void:
	layer = 15
	_build()
	visible = false
	Events.build_selection_changed.connect(_on_build_selection_changed)


func setup(build_controller: BuildController) -> void:
	controller = build_controller


func _process(_delta: float) -> void:
	if not visible or controller == null:
		return
	var blocker: String = controller.confirm_blocker()
	_confirm.disabled = not blocker.is_empty()
	_hint.text = blocker if not blocker.is_empty() else "Двигайте карту или коснитесь клетки"
	_hint.add_theme_color_override(
		"font_color", Palette.BAD if not blocker.is_empty() else Palette.UI_TEXT_DIM
	)


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UiTheme.shared()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	UiWidgets.bind_to_viewport(_root)

	var margins: Vector4i = UiTheme.safe_area_margins()
	var holder := MarginContainer.new()
	holder.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	holder.add_theme_constant_override("margin_left", margins.x)
	holder.add_theme_constant_override("margin_right", margins.z)
	# Над нижней панелью HUD, чтобы не перекрывать её кнопки.
	holder.add_theme_constant_override("margin_bottom", margins.w + UiTheme.TOUCH_LARGE + UiTheme.PAD_M)
	_root.add_child(holder)

	var panel := PanelContainer.new()
	holder.add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTheme.PAD_M)
	panel.add_child(row)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	row.add_child(text)

	_title = UiWidgets.label("", UiTheme.FONT_NORMAL)
	_title.name = "Title"
	text.add_child(_title)

	_hint = UiWidgets.label("", UiTheme.FONT_SMALL, Palette.UI_TEXT_DIM)
	_hint.name = "Hint"
	text.add_child(_hint)

	var cancel: Button = UiWidgets.text_button("Отмена", UiTheme.TOUCH_MIN * 2)
	cancel.name = "CancelButton"
	cancel.pressed.connect(_on_cancel)
	row.add_child(cancel)

	_confirm = UiWidgets.text_button("Поставить", UiTheme.TOUCH_MIN * 3)
	_confirm.name = "ConfirmButton"
	_confirm.custom_minimum_size.y = UiTheme.TOUCH_LARGE
	_confirm.pressed.connect(_on_confirm)
	row.add_child(_confirm)


func _on_build_selection_changed(def_id: StringName) -> void:
	visible = def_id != &""
	if visible:
		_title.text = BuildingDefs.display_name(def_id)


func _on_confirm() -> void:
	if controller != null:
		controller.confirm()


func _on_cancel() -> void:
	if controller != null:
		controller.cancel_building()
