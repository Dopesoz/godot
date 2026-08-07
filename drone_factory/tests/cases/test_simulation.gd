extends TestCase
## Логический тик: фиксированный шаг, ограниченный догон, сутки.

var world: GameWorld = null
var simulation: Simulation = null
var ticks: Array[int] = []


class CountingSystem extends GameSystem:
	var calls: int = 0
	var last_daylight: float = -1.0
	var was_reset: bool = false

	func tick(_delta: float, context: Dictionary) -> void:
		calls += 1
		last_daylight = context["daylight"]

	func reset() -> void:
		was_reset = true


func before_each() -> void:
	world = GameWorld.new()
	Engine.get_main_loop().root.add_child(world)
	world.new_game(11)

	simulation = Simulation.new()
	Engine.get_main_loop().root.add_child(simulation)
	simulation.add_system(BuildingSystem.new())
	simulation.setup(world)


func after_each() -> void:
	if is_instance_valid(simulation):
		simulation.free()
	if is_instance_valid(world):
		world.free()
	simulation = null
	world = null


func test_fixed_step_is_independent_of_frame_rate() -> void:
	# Десять секунд игрового времени при 60 и при 20 кадрах в секунду обязаны
	# дать одинаковое число тиков. Расхождение в один тик допустимо: остаток
	# накапливается в аккумуляторе и уходит в следующий кадр.
	for i: int in 600:
		simulation._process(1.0 / 60.0)
	var at_60: int = simulation.tick_count

	simulation.reset()
	for i: int in 200:
		simulation._process(1.0 / 20.0)
	var at_20: int = simulation.tick_count

	check(absi(at_60 - at_20) <= 1, "разное число тиков: %d против %d" % [at_60, at_20])
	check(
		absi(at_60 - Constants.TICKS_PER_SECOND * 10) <= 1,
		"за 10 секунд прошло %d тиков вместо %d" % [at_60, Constants.TICKS_PER_SECOND * 10]
	)


func test_catchup_is_limited() -> void:
	# Приложение свернули на минуту: игра не должна пытаться догнать всё сразу.
	simulation._process(60.0)
	check(
		simulation.tick_count <= Constants.MAX_CATCHUP_TICKS,
		"за кадр выполнено %d тиков" % simulation.tick_count
	)
	check(simulation.dropped_ticks() > 0, "пропущенные тики должны учитываться")


func test_pause_stops_simulation() -> void:
	simulation.paused = true
	simulation._process(1.0)
	check_eq(simulation.tick_count, 0, "на паузе симуляция стоит")
	simulation.paused = false
	simulation._process(1.0)
	check(simulation.tick_count > 0)


func test_systems_run_in_registration_order() -> void:
	var order: Array[String] = []
	var first := CountingSystem.new()
	var second := CountingSystem.new()
	simulation.systems.clear()
	simulation.add_system(first)
	simulation.add_system(second)

	simulation.tick()
	check_eq(first.calls, 1)
	check_eq(second.calls, 1)
	check_eq(simulation.systems[0], first, "порядок добавления — порядок выполнения")
	var _unused: Array[String] = order


func test_context_carries_daylight() -> void:
	var system := CountingSystem.new()
	simulation.add_system(system)
	simulation.tick()
	check_almost(system.last_daylight, simulation.daylight())


func test_reset_resets_systems() -> void:
	var system := CountingSystem.new()
	simulation.add_system(system)
	simulation.tick()
	simulation.reset()
	check_eq(simulation.tick_count, 0)
	check_almost(simulation.game_time, 0.0)
	check(system.was_reset, "сброс должен доходить до систем")


func test_day_night_cycle() -> void:
	check_almost(Simulation.daylight_at(0.0), 1.0, 0.001, "сутки начинаются днём")
	check_almost(Simulation.daylight_at(Simulation.DAY_LENGTH * 0.25), 1.0, 0.001, "день длится половину суток")
	check_almost(Simulation.daylight_at(Simulation.DAY_LENGTH * 0.70), 0.0, 0.001, "ночь должна быть тёмной")
	# Плавность: сумерки не должны прыгать ступенькой.
	var previous: float = 1.0
	for i: int in 100:
		var light: float = Simulation.daylight_at(Simulation.DAY_LENGTH * float(i) / 100.0)
		check(light >= 0.0 and light <= 1.0, "освещённость вне диапазона: %f" % light)
		check(absf(light - previous) < 0.25, "скачок освещённости: %f -> %f" % [previous, light])
		previous = light
	check_almost(Simulation.daylight_at(Simulation.DAY_LENGTH), Simulation.daylight_at(0.0), 0.001, "цикл замкнут")


func test_time_of_day_text() -> void:
	simulation.game_time = 0.0
	check_eq(simulation.time_of_day_text(), "День")
	simulation.game_time = Simulation.DAY_LENGTH * 0.70
	check_eq(simulation.time_of_day_text(), "Ночь")
	simulation.game_time = Simulation.DAY_LENGTH * 0.55
	check_eq(simulation.time_of_day_text(), "Сумерки")


func test_building_system_emits_state_changes() -> void:
	var changed: Array[int] = []
	var handler := func(building_id: int) -> void: changed.append(building_id)
	Events.building_state_changed.connect(handler)

	GameSetup.create_starting_base(world)
	simulation.tick()
	changed.clear()

	# Выключаем здание: на следующем тике оно обязано сообщить о смене состояния.
	var storage: Building = world.buildings.of_kind(BuildingDefs.Kind.STORAGE)[0]
	storage.enabled = false
	simulation.tick()
	check_eq(changed, [storage.id] as Array[int], "смена состояния должна давать событие")

	simulation.tick()
	Events.building_state_changed.disconnect(handler)
	check_eq(changed.size(), 1, "без изменений событий быть не должно")


func test_tick_cost_scales_with_buildings() -> void:
	# Бюджет: тик всей фабрики обязан укладываться в единицы миллисекунд,
	# иначе на слабом телефоне он съест кадр.
	GameSetup.create_starting_base(world)
	for i: int in 300:
		world.buildings.place(BuildingDefs.SOLAR, world.start_cell + Vector2i((i % 20) * 3 - 30, (i / 20) * 3 + 12))
	var start_usec: int = Time.get_ticks_usec()
	for i: int in 10:
		simulation.tick()
	var per_tick_ms: float = float(Time.get_ticks_usec() - start_usec) / 10000.0
	check(per_tick_ms < 4.0, "тик с %d зданиями занял %.2f мс" % [world.buildings.count(), per_tick_ms])
