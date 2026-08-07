extends TestCase
## Тема и виджеты: размеры под палец и корректная сборка элементов.


func before_each() -> void:
	Art.build()


func test_theme_has_required_styles() -> void:
	var theme: Theme = UiTheme.build()
	check(theme.has_stylebox("panel", "PanelContainer"), "нет фона панели")
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		check(theme.has_stylebox(state, "Button"), "нет стиля кнопки: %s" % state)
	check(theme.has_stylebox("fill", "ProgressBar"), "нет заливки полосы прогресса")
	check_eq(theme.default_font_size, UiTheme.FONT_NORMAL)


func test_pressed_state_is_visually_distinct() -> void:
	# На телефоне нет наведения: нажатие обязано отличаться цветом.
	var theme: Theme = UiTheme.build()
	var normal: StyleBoxFlat = theme.get_stylebox("normal", "Button")
	var pressed: StyleBoxFlat = theme.get_stylebox("pressed", "Button")
	check_ne(normal.bg_color, pressed.bg_color, "нажатая кнопка должна выглядеть иначе")


func test_touch_targets_are_large_enough() -> void:
	var button: Button = UiWidgets.text_button("Строить")
	check(button.custom_minimum_size.y >= UiTheme.TOUCH_MIN, "кнопка ниже минимальной цели касания")
	var icon: Button = UiWidgets.icon_button(BuildingDefs.DRILL, "Бур")
	check(icon.custom_minimum_size.x >= UiTheme.TOUCH_MIN)
	check(icon.custom_minimum_size.y >= UiTheme.TOUCH_MIN)
	icon.free()
	button.free()


func test_icon_button_uses_atlas_icon() -> void:
	var button: Button = UiWidgets.icon_button(Items.GEAR, "Шестерня")
	var icon: TextureRect = button.get_child(0).get_child(0)
	check_eq(icon.texture, Art.icon(Items.GEAR), "иконка должна браться из атласа")
	check_eq(button.focus_mode, Control.FOCUS_NONE, "фокус на телефоне не нужен")
	button.free()


func test_panel_and_scroll_helpers() -> void:
	var panel: PanelContainer = UiWidgets.panel()
	check(UiWidgets.panel_content(panel) != null, "панель должна иметь контейнер содержимого")
	panel.free()

	var scroll: ScrollContainer = UiWidgets.scroll_list()
	check(UiWidgets.scroll_list_content(scroll) != null, "список должен иметь контейнер строк")
	check_eq(scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED,
		"горизонтальная прокрутка мешает вертикальным спискам на телефоне")
	scroll.free()


func test_clear_children() -> void:
	var box := VBoxContainer.new()
	box.add_child(Label.new())
	box.add_child(Label.new())
	UiWidgets.clear_children(box)
	check_eq(box.get_child_count(), 0)
	box.free()


func test_short_number() -> void:
	check_eq(UiWidgets.short_number(0), "0")
	check_eq(UiWidgets.short_number(999), "999")
	check_eq(UiWidgets.short_number(1200), "1.2к")
	check_eq(UiWidgets.short_number(2500000), "2.5м")


func test_safe_area_margins_are_never_zero() -> void:
	# Даже без «чёлки» интерфейс не должен липнуть к краю экрана.
	var margins: Vector4i = UiTheme.safe_area_margins()
	check(margins.x >= UiTheme.PAD_M and margins.y >= UiTheme.PAD_M)
	check(margins.z >= UiTheme.PAD_M and margins.w >= UiTheme.PAD_M)
