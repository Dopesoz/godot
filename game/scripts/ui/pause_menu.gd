class_name PauseMenu
extends CenterContainer

## What the ☰ button opens: the game is paused, and from here the player can
## change the settings, save, or leave for the main menu.
##
## It reuses SettingsPanel rather than repeating it, and it restores the clock
## to whatever it was doing before — a player who had already paused does not
## want the town started for them on the way out.

signal closed()

const BUTTON_SIZE := Vector2(260, 48)

var _was_paused: bool
var _column: VBoxContainer
var _settings: SettingsPanel


func _init(was_paused: bool = false) -> void:
	_was_paused = was_paused
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var panel := PanelContainer.new()
	UiTheme.apply(panel)
	add_child(panel)

	_column = VBoxContainer.new()
	_column.add_theme_constant_override(&"separation", 10)
	panel.add_child(_column)

	var title := Label.new()
	title.text = tr("Paused")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", roundi(24 * Platform.ui_scale()))
	_column.add_child(title)

	_add_button(tr("Continue"), _leave)
	_add_button(tr("Settings"), _open_settings)
	_add_button(tr("Save town"), func() -> void:
		SaveManager.save_game(GameConstants.SAVE_SLOT_MAIN)
		EventBus.notify(tr("Town saved")))
	_add_button(tr("Main menu"), func() -> void:
		GameClock.set_speed_index(1)
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn"))

	_settings = SettingsPanel.new()
	_settings.visible = false
	_settings.closed.connect(func() -> void:
		_settings.visible = false
		_column.visible = true)
	add_child(_settings)


func _add_button(text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = BUTTON_SIZE * Platform.ui_scale()
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	_column.add_child(button)


func _open_settings() -> void:
	_settings.refresh()
	_settings.visible = true
	_column.visible = false


func _leave() -> void:
	if not _was_paused and GameClock.is_paused():
		GameClock.toggle_pause()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(InputActions.BUILD_CANCEL):
		get_viewport().set_input_as_handled()
		_leave()
