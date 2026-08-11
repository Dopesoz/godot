extends PanelContainer

## Build toolbar. Sends commands down to BuildController and reflects state
## coming back up through the EventBus — the UI never mutates the world itself.
##
## Buttons are deliberately large (design doc §26): the same layout has to work
## under a thumb on a phone, so nothing here is smaller than 44 px.

const MIN_BUTTON_SIZE := Vector2(96, 48)
## On a phone the bar has to fit ten tools across a five-inch screen. Buttons
## get shorter, never thinner than a fingertip, and the labels lose their
## keyboard hints — there is no keyboard.
const MOBILE_BUTTON_SIZE := Vector2(64, 56)

## Tool buttons, in the order they appear. Keyboard shortcut, label, tool mode.
const TOOLS := [
	[KEY_1, "Select", GameEnums.ToolMode.NONE],
	[KEY_2, "Wall", GameEnums.ToolMode.WALL],
	[KEY_3, "Door", GameEnums.ToolMode.DOOR],
	[KEY_4, "Window", GameEnums.ToolMode.WINDOW],
	[KEY_5, "Floor", GameEnums.ToolMode.FLOOR],
	[KEY_6, "Room", GameEnums.ToolMode.ASSIGN_ROOM],
	[KEY_7, "Furniture", GameEnums.ToolMode.FURNITURE],
	[KEY_8, "Plot", GameEnums.ToolMode.PLACE_LOT],
	[KEY_9, "Move in", GameEnums.ToolMode.MOVE_IN],
	[KEY_0, "Delete", GameEnums.ToolMode.DELETE],
]

## Room types the player can assign in the MVP (design doc §9).
const ROOM_TYPES := [
	GameEnums.RoomType.LIVING_ROOM,
	GameEnums.RoomType.BEDROOM,
	GameEnums.RoomType.KITCHEN,
	GameEnums.RoomType.BATHROOM,
]

@onready var _tool_row: HBoxContainer = %ToolRow
@onready var _option_row: HBoxContainer = %OptionRow
@onready var _floor_picker: OptionButton = %FloorPicker
@onready var _room_picker: OptionButton = %RoomPicker
@onready var _furniture_picker: OptionButton = %FurniturePicker
@onready var _plot_picker: OptionButton = %PlotPicker
@onready var _family_picker: OptionButton = %FamilyPicker
@onready var _rotate_button: Button = %RotateButton
@onready var _message: Label = %Message

var _builder: BuildController
var _buttons: Dictionary = {}
var _message_timer: float = 0.0


func _ready() -> void:
	_apply_safe_area()
	var world := get_tree().get_first_node_in_group(&"world")
	_builder = world.get_node("Builder") as BuildController if world != null else null

	_build_tool_buttons()
	_fill_floor_picker()
	_fill_room_picker()
	_fill_furniture_picker()
	_fill_plot_picker()
	_fill_family_picker()

	_floor_picker.item_selected.connect(_on_floor_selected)
	_room_picker.item_selected.connect(_on_room_selected)
	_furniture_picker.item_selected.connect(_on_furniture_selected)
	_rotate_button.pressed.connect(_on_rotate_pressed)
	_plot_picker.item_selected.connect(_on_plot_selected)
	_family_picker.item_selected.connect(_on_family_selected)
	EventBus.tool_mode_changed.connect(_on_tool_mode_changed)
	EventBus.build_rejected.connect(_on_build_rejected)
	EventBus.rooms_rebuilt.connect(_on_rooms_rebuilt)
	_on_tool_mode_changed(GameEnums.ToolMode.NONE)


## Keeps the bar clear of a notch or a gesture bar. Zero on hardware without
## them, so desktop is untouched.
func _apply_safe_area() -> void:
	var margins := Platform.safe_area_margins()
	if margins == Vector4i.ZERO:
		return
	offset_bottom -= float(margins.w)
	offset_left += float(margins.x)
	offset_right -= float(margins.z)


## The bar is anchored to the bottom edge, so its height is a top offset, and a
## fixed one left a slab of empty panel under the buttons whenever the option
## row was hidden. Re-measuring after every layout change keeps the panel the
## size of what is actually in it — which on a phone is most of the screen.
func _fit_height() -> void:
	var wanted := get_combined_minimum_size().y
	var top := offset_bottom - wanted
	if not is_equal_approx(top, offset_top):
		offset_top = top


func _build_tool_buttons() -> void:
	var touch := Platform.has_touch()
	var size := (MOBILE_BUTTON_SIZE if touch else MIN_BUTTON_SIZE) * Platform.ui_scale()
	for entry in TOOLS:
		var button := Button.new()
		button.text = entry[1] if touch else "%s\n%s" % [entry[1], OS.get_keycode_string(entry[0])]
		button.custom_minimum_size = size
		button.clip_text = true
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_tool_button.bind(entry[2] as int))
		_tool_row.add_child(button)
		_buttons[entry[2]] = button


func _fill_floor_picker() -> void:
	_floor_picker.clear()
	for material in Database.all_floors():
		_floor_picker.add_item("%s  $%d" % [material.display_name, material.price_per_tile])
		_floor_picker.set_item_metadata(_floor_picker.item_count - 1, material.id)
	if _floor_picker.item_count > 0:
		_floor_picker.select(0)
		_on_floor_selected(0)


func _fill_room_picker() -> void:
	_room_picker.clear()
	for room_type: int in ROOM_TYPES:
		_room_picker.add_item(String(GameEnums.RoomType.keys()[room_type]).capitalize())
		_room_picker.set_item_metadata(_room_picker.item_count - 1, room_type)
	_room_picker.select(0)
	_on_room_selected(0)


## Furniture is listed by category so a long catalogue stays navigable; the
## picker is filled from the Database, so adding a .tres adds a menu entry.
func _fill_furniture_picker() -> void:
	_furniture_picker.clear()
	for category: int in FurnitureData.Category.values():
		var entries := Database.furniture_in_category(category)
		if entries.is_empty():
			continue
		_furniture_picker.add_separator(String(FurnitureData.Category.keys()[category]).capitalize())
		for template in entries:
			_furniture_picker.add_item("%s  $%d" % [template.display_name, template.price])
			_furniture_picker.set_item_metadata(_furniture_picker.item_count - 1, template.id)
	# Skip the leading separator when selecting the default entry.
	for index in _furniture_picker.item_count:
		if _furniture_picker.get_item_metadata(index) != null:
			_furniture_picker.select(index)
			_on_furniture_selected(index)
			break


func _fill_plot_picker() -> void:
	_plot_picker.clear()
	for id: StringName in Database.buildings.keys():
		var template: BuildingData = Database.buildings[id]
		_plot_picker.add_item("%s  %dx%d  $%d" % [
				template.display_name, template.size.x, template.size.y, template.price])
		_plot_picker.set_item_metadata(_plot_picker.item_count - 1, template.id)
	if _plot_picker.item_count > 0:
		_plot_picker.select(0)
		_on_plot_selected(0)


func _fill_family_picker() -> void:
	_family_picker.clear()
	for count in [1, 2, 3, 4]:
		_family_picker.add_item("%d resident%s" % [count, "" if count == 1 else "s"])
		_family_picker.set_item_metadata(_family_picker.item_count - 1, count)
	_family_picker.select(1)
	_on_family_selected(1)


## Number keys select tools. Handled here rather than as InputMap actions
## because the tool list grows every phase and each entry would otherwise need
## its own action registered up front.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	for entry in TOOLS:
		if key.physical_keycode == entry[0]:
			_on_tool_button(entry[2] as int)
			get_viewport().set_input_as_handled()
			return


func _process(delta: float) -> void:
	if _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.0:
			_message.text = ""


func _on_tool_button(mode: int) -> void:
	if _builder != null:
		_builder.set_tool(mode)


func _on_tool_mode_changed(mode: int) -> void:
	for tool_mode: int in _buttons:
		(_buttons[tool_mode] as Button).button_pressed = tool_mode == mode
	_floor_picker.visible = mode == GameEnums.ToolMode.FLOOR
	_room_picker.visible = mode == GameEnums.ToolMode.ASSIGN_ROOM
	_furniture_picker.visible = mode == GameEnums.ToolMode.FURNITURE
	_rotate_button.visible = mode == GameEnums.ToolMode.FURNITURE
	_plot_picker.visible = mode == GameEnums.ToolMode.PLACE_LOT
	_family_picker.visible = mode == GameEnums.ToolMode.MOVE_IN
	_option_row.visible = (_floor_picker.visible or _room_picker.visible
			or _furniture_picker.visible or _plot_picker.visible or _family_picker.visible)
	# Deferred: the container has not re-measured itself yet this frame.
	_fit_height.call_deferred()


func _on_floor_selected(index: int) -> void:
	if _builder != null:
		_builder.selected_floor_id = _floor_picker.get_item_metadata(index)


func _on_room_selected(index: int) -> void:
	if _builder != null:
		_builder.selected_room_type = int(_room_picker.get_item_metadata(index))


func _on_furniture_selected(index: int) -> void:
	var id: Variant = _furniture_picker.get_item_metadata(index)
	if _builder != null and id != null:
		_builder.selected_furniture_id = id


## Rotation has a button as well as the R key: there is no keyboard on a phone.
func _on_rotate_pressed() -> void:
	if _builder != null:
		_builder.rotation_steps = (_builder.rotation_steps + 1) % 4


func _on_plot_selected(index: int) -> void:
	var id: Variant = _plot_picker.get_item_metadata(index)
	if _builder != null and id != null:
		_builder.selected_building_id = id


func _on_family_selected(index: int) -> void:
	if _builder != null:
		_builder.household_size = int(_family_picker.get_item_metadata(index))


func _on_build_rejected(reason: String) -> void:
	_message.text = reason
	_message.add_theme_color_override("font_color", Color(1.0, 0.55, 0.5))
	_message_timer = 2.5


func _on_rooms_rebuilt(_building_id: int, rooms: Array) -> void:
	var sealed := 0
	for room: Room in rooms:
		if not room.is_reachable():
			sealed += 1
	var text := "%d room(s)" % rooms.size()
	if sealed > 0:
		text += " — %d without a door" % sealed
	_message.text = text
	_message.add_theme_color_override("font_color", Color(0.76, 0.82, 0.9))
	_message_timer = 3.0
