extends TestCase
## Панель исследований: разделы списка, запуск, прогресс, отмена.

var world: GameWorld = null
var simulation: Simulation = null
var research: ResearchSystem = null
var panel: ResearchPanel = null


func before_each() -> void:
	world = GameWorld.new()
	Engine.get_main_loop().root.add_child(world)
	world.new_game(2828)
	simulation = Simulation.new()
	Engine.get_main_loop().root.add_child(simulation)
	research = ResearchSystem.new()
	simulation.add_system(research)
	simulation.setup(world)

	panel = ResearchPanel.new()
	Engine.get_main_loop().root.add_child(panel)
	panel.setup(research, world.research)


func after_each() -> void:
	for node: Node in [panel, simulation, world]:
		if is_instance_valid(node):
			node.free()
	world = null
	simulation = null
	research = null
	panel = null


func row(tech_id: StringName) -> Button:
	return panel.find_child(String(tech_id), true, false) as Button


func test_all_technologies_are_listed() -> void:
	panel.open()
	for tech_id: StringName in Technologies.all_ids():
		check(row(tech_id) != null, "в списке нет технологии %s" % tech_id)


func test_locked_technology_shows_prerequisites() -> void:
	panel.open()
	var gated: Button = row(Technologies.MINING_2)
	check(gated.disabled, "технология с невыполненными предшественниками недоступна")
	var detail: Label = gated.find_child("Detail", true, false) as Label
	check(detail.text.begins_with("Сначала:"), "игроку нужно видеть, чего не хватает: %s" % detail.text)


func test_available_technology_shows_cost() -> void:
	panel.open()
	var detail: Label = row(Technologies.MINING_1).find_child("Detail", true, false) as Label
	check(detail.text.contains("колба"), "в строке должна быть цена: %s" % detail.text)


func test_starting_research_updates_header() -> void:
	panel.open()
	row(Technologies.MINING_1).pressed.emit()
	check_eq(research.current, Technologies.MINING_1)
	check_eq(panel._current_label.text, Technologies.display_name(Technologies.MINING_1))
	check(panel._cost_label.text.begins_with("Осталось:"))
	check(panel._cancel_button.visible, "во время исследования доступна отмена")


func test_progress_bar_follows_research() -> void:
	panel.open()
	research.start(Technologies.MINING_1)
	research.invested[Items.SCIENCE_RED] = int(Technologies.total_cost(Technologies.MINING_1) / 2)
	Events.research_progress_changed.emit(Technologies.MINING_1, research.progress())
	check_almost(panel._progress.value, 0.5, 0.05, "полоска должна показывать половину пути")


func test_cancel_clears_current() -> void:
	panel.open()
	research.start(Technologies.MINING_1)
	panel._cancel_button.pressed.emit()
	check_eq(research.current, &"")
	check_eq(panel._current_label.text, "Ничего не изучается")
	check(not panel._cancel_button.visible)


func test_completed_technology_moves_to_done() -> void:
	panel.open()
	world.research.complete(Technologies.MINING_1)
	Events.research_completed.emit(Technologies.MINING_1)
	var detail: Label = row(Technologies.MINING_1).find_child("Detail", true, false) as Label
	check(detail.text.begins_with("Изучено"), "изученная технология должна помечаться")
	check(row(Technologies.MINING_1).disabled, "повторно изучать нельзя")
	world.research.complete(Technologies.ELECTRONICS)
	Events.research_completed.emit(Technologies.ELECTRONICS)
	check(not row(Technologies.MINING_2).disabled, "открывшаяся технология должна стать доступной")


func test_touch_targets() -> void:
	panel.open()
	for tech_id: StringName in Technologies.all_ids():
		check(row(tech_id).custom_minimum_size.y >= UiTheme.TOUCH_MIN, "строка %s мелковата" % tech_id)


func test_rows_fit_a_phone_screen() -> void:
	# Строка технологии обрезается, а не ломает раскладку, — но обрезанное
	# описание всё равно бесполезно. Меряем настоящую ширину текста.
	var budget: float = 648.0
	for tech_id: StringName in Technologies.all_ids():
		var text: String = "%s · %s" % [
			ResearchPanel._cost_text(tech_id), Technologies.description(tech_id),
		]
		var probe: Label = UiWidgets.label(text, UiTheme.FONT_SMALL)
		var width: float = probe.get_combined_minimum_size().x
		probe.free()
		check(width <= budget, "строка технологии %s требует %.0f при %.0f: «%s»" % [
			tech_id, width, budget, text,
		])
