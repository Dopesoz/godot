extends TestCase
## HUD: показатели, тосты, кнопки нижней панели.

var world: GameWorld = null
var simulation: Simulation = null
var hud: Hud = null


func before_each() -> void:
	world = GameWorld.new()
	Engine.get_main_loop().root.add_child(world)
	simulation = Simulation.new()
	Engine.get_main_loop().root.add_child(simulation)
	world.simulation = simulation
	world.new_game(4545)
	# Строка задачи в HUD берётся из сюжета — без него проверять нечего.
	simulation.add_system(StorySystem.new())
	simulation.setup(world)
	GameSetup.create_starting_base(world)

	hud = Hud.new()
	Engine.get_main_loop().root.add_child(hud)
	hud.setup(world, simulation)


func after_each() -> void:
	if is_instance_valid(hud):
		hud.free()
	if is_instance_valid(simulation):
		simulation.free()
	if is_instance_valid(world):
		world.free()
	world = null
	simulation = null
	hud = null


func find_button(name: String) -> Button:
	return hud.find_child(name, true, false) as Button


func test_bottom_bar_has_main_actions() -> void:
	for name: String in ["BuildButton", "ResearchButton", "MenuButton"]:
		var button: Button = find_button(name)
		check(button != null, "нет кнопки %s" % name)
		if button != null:
			check(
				button.custom_minimum_size.y >= UiTheme.TOUCH_MIN,
				"кнопка %s мельче цели касания" % name
			)


func test_buttons_emit_requests() -> void:
	var opened: Array[String] = []
	hud.build_menu_requested.connect(func() -> void: opened.append("build"))
	hud.research_requested.connect(func() -> void: opened.append("research"))
	hud.menu_requested.connect(func() -> void: opened.append("menu"))

	find_button("BuildButton").pressed.emit()
	find_button("ResearchButton").pressed.emit()
	find_button("MenuButton").pressed.emit()
	check_eq(opened, ["build", "research", "menu"] as Array[String])


func test_stats_show_stored_resources() -> void:
	hud._refresh_stats()
	var found: bool = false
	for row: Node in hud._stats_box.get_children():
		var value: Label = row.get_node("Value")
		if value.text != "0":
			found = true
	check(found, "верхняя панель должна показывать стартовые запасы")


func test_stats_refresh_is_throttled() -> void:
	# Событий об инвентаре сотни в секунду: пересчёт не должен идти на каждое.
	hud._stats_dirty = false
	Events.inventory_changed.emit(0)
	check(hud._stats_dirty, "событие должно помечать панель устаревшей")
	hud._process(0.1)
	check(hud._stats_dirty, "раньше интервала пересчёта быть не должно")
	hud._process(Hud.STATS_REFRESH_INTERVAL)
	check(not hud._stats_dirty, "по истечении интервала панель должна обновиться")


func test_power_label_colours_by_satisfaction() -> void:
	Events.power_stats_changed.emit(100.0, 50.0, 1.0)
	check_eq(hud._power_label.get_theme_color("font_color"), Palette.ENERGY, "избыток — спокойный цвет")
	Events.power_stats_changed.emit(30.0, 100.0, 0.3)
	check_eq(hud._power_label.get_theme_color("font_color"), Palette.BAD, "сильная нехватка — тревожный цвет")
	Events.power_stats_changed.emit(80.0, 100.0, 0.8)
	check_eq(hud._power_label.get_theme_color("font_color"), Palette.WARN, "лёгкая нехватка — предупреждение")


func test_drone_counter() -> void:
	Events.drone_count_changed.emit(3, 5)
	check_eq(hud._drones_label.text, "Курьеры 3/5")


func test_toast_shows_and_fades() -> void:
	Events.notify.emit("Склад построен")
	check(hud.is_toast_visible())
	check_eq(hud.toast_text(), "Склад построен")
	hud._process(Hud.TOAST_TIME + 0.1)
	check(not hud.is_toast_visible(), "сообщение должно исчезать само")


func test_time_of_day_is_shown() -> void:
	simulation.game_time = Simulation.DAY_LENGTH * 0.7
	hud._process(0.016)
	check_eq(hud._time_label.text, "Ночь")


func test_fps_counter_can_be_hidden() -> void:
	hud.show_fps = false
	hud._process(0.016)
	check(not hud._fps_label.visible)
	hud.show_fps = true
	hud._process(0.016)
	check(hud._fps_label.visible)
	check(hud._fps_label.text.ends_with("FPS"))


func test_empty_space_passes_touches_to_map() -> void:
	# Иначе карта перестанет двигаться пальцем в середине экрана.
	var root: Control = hud.get_node("Root")
	check_eq(root.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_home_button_exists_and_reports() -> void:
	var pressed: Array[int] = [0]
	hud.home_requested.connect(func() -> void: pressed[0] += 1)
	var button: Button = find_button("HomeButton")
	check(button != null, "нужна кнопка возврата к базе")
	if button == null:
		return
	check(button.custom_minimum_size.y >= UiTheme.TOUCH_MIN, "кнопка мельче цели касания")
	button.pressed.emit()
	check_eq(pressed[0], 1, "кнопка должна сообщать о нажатии")


func test_home_cell_points_at_the_port() -> void:
	var ports: Array[Building] = world.buildings.of_kind(BuildingDefs.Kind.DRONE_PORT)
	check(not ports.is_empty(), "в стартовой базе есть порт")
	check_eq(world.home_cell(), ports[0].center_cell(), "домой — это порт дронов")


func test_home_cell_falls_back_to_start() -> void:
	world.buildings.clear()
	check_eq(world.home_cell(), world.start_cell, "без зданий возвращаемся к точке старта")


func test_top_bar_fits_narrow_screen() -> void:
	# Верхняя панель не должна вылезать за базовую ширину: на узком экране
	# показатели обрежутся, и игрок увидит «поломанный» интерфейс.
	hud._refresh_stats()
	var base_width: float = float(ProjectSettings.get_setting(
		"display/window/size/viewport_width", 720
	))
	var margins: Vector4i = UiTheme.safe_area_margins()
	var available: float = base_width - float(margins.x + margins.z)
	var needed: float = hud._top_bar.get_combined_minimum_size().x
	check(needed <= available, "верхняя панель требует %.0f при доступных %.0f" % [needed, available])


func test_objective_line_fits_narrow_screen() -> void:
	hud.refresh_objective()
	var button: Button = hud.find_child("ObjectiveButton", true, false) as Button
	check(button != null, "нужна строка задачи")
	check(not hud.objective_text().is_empty(), "задача должна быть написана")
	check(
		button.get_combined_minimum_size().x <= 400.0,
		"длинная задача не должна растягивать панель: %.0f" % button.get_combined_minimum_size().x
	)
	# Обрезка на полуслове — то, что игрок видел на телефоне: текст обязан
	# переноситься на вторую строку.
	var label: Label = hud.find_child("ObjectiveLabel", true, false) as Label
	check_eq(label.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART)
	check(label.max_lines_visible >= 2, "под задачу нужно две строки")
