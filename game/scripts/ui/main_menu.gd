extends Control

## The first screen: play, settings, quit.
##
## It exists for a reason beyond convention. Until now the game went straight
## from the self-test into a running city, which meant the music started, the
## clock started, and a player who only wanted to turn the volume down had to
## find a key for it while a town ran in the background. A menu is where the
## settings can be reached before anything is happening.
##
## Continue is offered only when there is something to continue: an empty slot
## button that says "no save" is worse than no button.

const WORLD_SCENE := "res://scenes/world/world.tscn"
const SAVE_SLOT := GameConstants.SAVE_SLOT_MAIN
const BUTTON_SIZE := Vector2(280, 52)

var _settings: SettingsPanel
var _buttons: VBoxContainer
var _column: VBoxContainer
var _title: Label
var _subtitle: Label


## Command-line flags that mean "there is no player here": every tool that
## drives the game headlessly or takes a screenshot wants the town, not a menu
## waiting for a click that will never come.
const AUTOMATED_FLAGS := ["--screenshot", "--uitest", "--touchtest", "--report",
		"--bench", "--showroom", "--demo", "--empty"]


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var args := OS.get_cmdline_user_args()
	for flag: String in AUTOMATED_FLAGS:
		if args.has(flag):
			get_tree().change_scene_to_file.call_deferred(WORLD_SCENE)
			return
	AudioManager.play_music(&"main")

	var background := ColorRect.new()
	background.color = Color(0.07, 0.09, 0.11)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	# The whole column hides when the settings open: a CenterContainer stacks its
	# children on top of each other, so hiding only the buttons left the title
	# showing through the panel.
	_column = VBoxContainer.new()
	_column.add_theme_constant_override(&"separation", 12)
	centre.add_child(_column)
	var column := _column

	_title = Label.new()
	var title := _title
	title.text = tr("My City: Inside")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", roundi(38 * Platform.ui_scale()))
	column.add_child(title)

	_subtitle = Label.new()
	var subtitle := _subtitle
	subtitle.text = tr("Build a street, then look inside it")
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override(&"font_color", Color(0.66, 0.72, 0.80))
	column.add_child(subtitle)

	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override(&"separation", 10)
	column.add_child(_buttons)

	if SaveManager.has_slot(SAVE_SLOT):
		_add_button(tr("Continue"), _on_continue)
	_add_button(tr("New town"), _on_new_game)
	_add_button(tr("Settings"), _on_settings)
	if not Platform.is_mobile():
		_add_button(tr("Quit"), func() -> void: get_tree().quit())

	_settings = SettingsPanel.new()
	_settings.visible = false
	_settings.closed.connect(func() -> void:
		_settings.visible = false
		_column.visible = true
		# The language may have changed while the panel was open.
		_retranslate())
	centre.add_child(_settings)
	_maybe_screenshot()


## `--menushot out.png [settings]` photographs this screen and quits. The world
## has its own --screenshot, but that one starts the game, which is the one
## thing this screen is for not doing yet.
func _maybe_screenshot() -> void:
	var args := OS.get_cmdline_user_args()
	var index := args.find("--menushot")
	if index == -1:
		return
	var path := args[index + 1] if index + 1 < args.size() else "user://menu.png"
	if index + 2 < args.size() and args[index + 2] == "settings":
		_on_settings()
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()


## Rebuilds the menu's own text after a language change: buttons created in
## code keep whatever string they were given.
func _retranslate() -> void:
	for child in _column.get_children():
		if child is Label:
			continue
	_title.text = tr("My City: Inside")
	_subtitle.text = tr("Build a street, then look inside it")
	var labels := [tr("Continue"), tr("New town"), tr("Settings"), tr("Quit")]
	var index := 0
	if not SaveManager.has_slot(SAVE_SLOT):
		index = 1
	for button in _buttons.get_children():
		if button is Button and index < labels.size():
			(button as Button).text = labels[index]
			index += 1


func _add_button(text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = BUTTON_SIZE * Platform.ui_scale()
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	_buttons.add_child(button)


func _on_new_game() -> void:
	# A new town replaces the old one, so the old save must not be reloaded on
	# top of it later by accident.
	SaveManager.delete_slot(SAVE_SLOT)
	get_tree().change_scene_to_file(WORLD_SCENE)


func _on_continue() -> void:
	WorldController.load_on_start = true
	get_tree().change_scene_to_file(WORLD_SCENE)


func _on_settings() -> void:
	_settings.refresh()
	_settings.visible = true
	_column.visible = false
