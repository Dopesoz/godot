class_name SettingsPanel
extends PanelContainer

## The settings, built in code and used in two places: the main menu and the
## pause panel inside the game.
##
## Built in code rather than as a scene because it is the same panel in both
## places, and two .tscn files that must stay identical are two files that will
## not. Everything it changes goes straight into Settings, which saves itself —
## there is no "apply" button because there is nothing to apply.

const ROW_HEIGHT := 44

signal closed()

var _music: HSlider
var _sfx: HSlider
var _mute: CheckButton


func _init() -> void:
	UiTheme.apply(self)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override(&"separation", 10)
	add_child(layout)

	var title := Label.new()
	title.text = "Settings"
	title.add_theme_font_size_override(&"font_size", roundi(20 * Platform.ui_scale()))
	layout.add_child(title)

	_music = _add_slider(layout, "Music", Settings.music_volume)
	_music.value_changed.connect(func(value: float) -> void: Settings.set_music_volume(value))
	_sfx = _add_slider(layout, "Sound effects", Settings.sfx_volume)
	_sfx.value_changed.connect(func(value: float) -> void: Settings.set_sfx_volume(value))

	_mute = CheckButton.new()
	_mute.text = "Mute everything"
	_mute.button_pressed = Settings.muted
	_mute.custom_minimum_size.y = ROW_HEIGHT * Platform.ui_scale()
	_mute.toggled.connect(func(pressed: bool) -> void: AudioManager.set_muted(pressed))
	layout.add_child(_mute)

	var hint := Label.new()
	hint.text = "M mutes, E switches walls, Space pauses"
	hint.add_theme_color_override(&"font_color", Color(0.68, 0.72, 0.78))
	layout.add_child(hint)

	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size.y = ROW_HEIGHT * Platform.ui_scale()
	close.pressed.connect(func() -> void: closed.emit())
	layout.add_child(close)


func _add_slider(layout: VBoxContainer, label_text: String, value: float) -> HSlider:
	var row := VBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	# Wide enough to be dragged with a thumb, which is the only pointer this
	# game is guaranteed to have.
	slider.custom_minimum_size = Vector2(260, ROW_HEIGHT) * Platform.ui_scale()
	row.add_child(slider)
	layout.add_child(row)
	return slider


## Reflects settings changed elsewhere (the M key, another panel) without
## firing the change signals back at Settings.
func refresh() -> void:
	_music.set_value_no_signal(Settings.music_volume)
	_sfx.set_value_no_signal(Settings.sfx_volume)
	_mute.set_pressed_no_signal(Settings.muted)
