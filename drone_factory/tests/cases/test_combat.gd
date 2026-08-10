extends TestCase
## Жуки, стены и турели.
##
## Главное свойство, которое проверяется здесь, — не «жуки кусают», а то, что
## оборона решается один раз и не превращается в отдельную игру: гнёзда можно
## снести, стены принимают удар на себя, турель с патронами закрывает подходы.

var world: GameWorld = null
var simulation: Simulation = null
var combat: CombatSystem = null


func before_each() -> void:
	world = GameWorld.new()
	Engine.get_main_loop().root.add_child(world)
	world.new_game(4242)
	for i: int in world.grid.size * world.grid.size:
		world.grid.terrain[i] = TileTypes.Terrain.GRASS
		world.grid.ore[i] = TileTypes.Ore.NONE

	simulation = Simulation.new()
	Engine.get_main_loop().root.add_child(simulation)
	world.simulation = simulation
	simulation.add_system(PowerSystem.new())
	# Здания сами крутят свои часы (перезарядка, вспышка), поэтому без
	# системы зданий турель в тесте вела бы себя не как в игре.
	simulation.add_system(BuildingSystem.new())
	combat = CombatSystem.new()
	simulation.add_system(combat)
	simulation.setup(world)
	simulation.game_time = 0.0


func after_each() -> void:
	for node: Node in [simulation, world]:
		if is_instance_valid(node):
			node.free()
	world = null
	simulation = null
	combat = null


func place(def_id: StringName, offset: Vector2i) -> Building:
	return world.buildings.place(def_id, world.start_cell + offset)


func run_ticks(count: int) -> void:
	for i: int in count:
		simulation.tick()


## Ставит жука вплотную к зданию — ждать, пока он дойдёт сам, тест не должен.
func spawn_next_to(target: Building) -> Monster:
	var monster := Monster.new()
	monster.id = 1
	monster.max_health = 60
	monster.health = 60
	monster.position = target.center() + Vector2(Constants.TILE_SIZE, 0)
	monster.previous_position = monster.position
	combat.monsters.append(monster)
	return monster


func test_nests_appear_around_the_base_but_not_on_it() -> void:
	var placed: int = combat.populate_nests()
	check(placed > 0, "гнёзда не расставились")
	for nest: Building in world.buildings.of_kind(BuildingDefs.Kind.NEST):
		var distance: float = Vector2(nest.center_cell() - world.start_cell).length()
		check(
			distance >= float(CombatSystem.NEST_MIN_DISTANCE) - 4.0,
			"гнездо в %d клетках от базы — слишком близко" % int(distance)
		)


func test_first_wave_waits_out_the_grace_period() -> void:
	combat.populate_nests()
	simulation.game_time = CombatSystem.GRACE_PERIOD * 0.5
	run_ticks(5)
	check_eq(combat.wave_number, 0, "волна пришла раньше срока")

	simulation.game_time = CombatSystem.GRACE_PERIOD + 1.0
	run_ticks(2)
	check(combat.wave_number >= 1, "после льготного времени волна должна начаться")
	check(combat.alive_count() > 0, "волна без жуков")


func test_no_nests_means_no_waves() -> void:
	# Зачистка гнёзд — это и есть способ закончить с обороной навсегда.
	simulation.game_time = CombatSystem.GRACE_PERIOD + 100.0
	run_ticks(5)
	check_eq(combat.wave_number, 0, "без гнёзд волн быть не должно")


func test_monster_damages_and_destroys_a_building() -> void:
	var storage: Building = place(BuildingDefs.STORAGE, Vector2i(0, 0))
	var monster: Monster = spawn_next_to(storage)
	check_eq(storage.health, storage.max_health(), "новое здание должно быть целым")

	run_ticks(20)
	check(storage.health < storage.max_health(), "жук должен грызть здание")
	check_eq(monster.state, Monster.State.ATTACKING, "жук должен дойти и вцепиться")

	run_ticks(600)
	check_eq(
		world.buildings.get_building(storage.id), null,
		"без обороны здание в итоге должно быть разрушено"
	)


func test_wall_is_preferred_over_the_machine_behind_it() -> void:
	var storage: Building = place(BuildingDefs.STORAGE, Vector2i(0, 0))
	var wall: Building = place(BuildingDefs.WALL, Vector2i(3, 0))
	var monster := Monster.new()
	monster.id = 2
	monster.max_health = 60
	monster.health = 60
	monster.position = world.buildings.get_building(wall.id).center() + Vector2(48.0, 0.0)
	monster.previous_position = monster.position
	combat.monsters.append(monster)

	run_ticks(40)
	check_eq(monster.target_id, wall.id, "жук обязан вцепиться в стену, а не в склад")
	check_eq(storage.health, storage.max_health(), "склад за стеной не должен пострадать")


func test_turret_kills_a_monster_when_it_has_ammo_and_power() -> void:
	var turret: Turret = place(BuildingDefs.TURRET, Vector2i(0, 0)) as Turret
	turret.input.add(Items.AMMO, 40)
	# Турель ест ток: без панели рядом система питания её обесточит.
	place(BuildingDefs.SOLAR, Vector2i(0, 3))
	place(BuildingDefs.SOLAR, Vector2i(3, 3))

	var monster := Monster.new()
	monster.id = 3
	monster.max_health = 60
	monster.health = 60
	monster.position = turret.center() + Vector2(float(Constants.TILE_SIZE) * 4.0, 0.0)
	monster.previous_position = monster.position
	combat.monsters.append(monster)

	run_ticks(60)
	check(not monster.is_alive(), "турель с патронами должна убить жука")
	check(turret.input.count(Items.AMMO) < 40, "патроны должны расходоваться")


func test_turret_without_ammo_is_silent() -> void:
	var turret: Turret = place(BuildingDefs.TURRET, Vector2i(0, 0)) as Turret
	place(BuildingDefs.SOLAR, Vector2i(0, 3))
	var monster := Monster.new()
	monster.id = 4
	monster.max_health = 60
	monster.health = 60
	monster.position = turret.center() + Vector2(float(Constants.TILE_SIZE) * 3.0, 0.0)
	monster.previous_position = monster.position
	combat.monsters.append(monster)

	run_ticks(40)
	check(monster.is_alive(), "без патронов турель стрелять не может")
	check(turret.requests().has(Items.AMMO), "турель обязана просить патроны")


func test_turret_ignores_monsters_out_of_range() -> void:
	var turret: Turret = place(BuildingDefs.TURRET, Vector2i(0, 0)) as Turret
	turret.input.add(Items.AMMO, 40)
	place(BuildingDefs.SOLAR, Vector2i(0, 3))
	place(BuildingDefs.SOLAR, Vector2i(3, 3))
	var monster := Monster.new()
	monster.id = 5
	monster.max_health = 60
	monster.health = 60
	monster.position = turret.center() + Vector2(
		float(Constants.TILE_SIZE) * (Turret.RANGE_CELLS + 6.0), 0.0
	)
	monster.previous_position = monster.position
	combat.monsters.append(monster)

	run_ticks(10)
	check_eq(monster.health, 60, "по цели вне радиуса стрелять нельзя")


func test_damaged_buildings_survive_save_and_load() -> void:
	var storage: Building = place(BuildingDefs.STORAGE, Vector2i(0, 0))
	storage.take_damage(120)
	var wounded: int = storage.health
	var data: Array = world.buildings.serialize()

	var other_grid := Grid.new(world.grid.size)
	for i: int in other_grid.size * other_grid.size:
		other_grid.terrain[i] = TileTypes.Terrain.GRASS
	var other := BuildingRegistry.new(other_grid)
	other.deserialize(data)

	check_eq(
		other.get_building(storage.id).health, wounded,
		"повреждения должны переживать сохранение"
	)


func test_waves_survive_save_and_load() -> void:
	combat.populate_nests()
	simulation.game_time = CombatSystem.GRACE_PERIOD + 1.0
	run_ticks(2)
	var alive: int = combat.alive_count()
	check(alive > 0, "нужна живая волна для проверки")

	var data: Dictionary = combat.serialize()
	combat.reset()
	check_eq(combat.alive_count(), 0)
	combat.deserialize(data)
	check_eq(combat.alive_count(), alive, "жуки в пути потерялись при загрузке")
	check(combat.wave_number > 0, "номер волны потерялся")


## --- Танки и гнёзда --------------------------------------------------------

func build_depot(tanks: int) -> TankDepot:
	var depot: TankDepot = place(BuildingDefs.TANK_DEPOT, Vector2i(0, 0)) as TankDepot
	place(BuildingDefs.SOLAR, Vector2i(0, 5))
	depot.output.add(Items.TANK, tanks)
	depot.tick(Constants.TICK_DELTA, {})
	return depot


func test_nest_cannot_be_taken_apart_by_hand() -> void:
	var camera := GameCamera.new()
	camera.view_size_override = Vector2(720, 1280)
	world.add_child(camera)
	var controller := BuildController.new()
	Engine.get_main_loop().root.add_child(controller)
	controller.setup(world, camera)

	var nest: Building = place(BuildingDefs.NEST, Vector2i(10, 0))
	check(not BuildingDefs.can_demolish(BuildingDefs.NEST), "гнездо не должно разбираться")
	check(not controller.demolish(nest.id), "снос гнезда обязан быть отклонён")
	check(world.buildings.get_building(nest.id) != null, "гнездо должно остаться на месте")
	controller.free()


func test_depot_turns_items_into_tanks_and_asks_for_more() -> void:
	var depot: TankDepot = build_depot(2)
	check_eq(depot.tank_count(), 2, "танки должны выехать из ящиков")
	check(depot.requests().has(Items.TANK), "неполный ангар обязан просить технику")
	check_eq(depot.idle_tanks().size(), 2, "новые танки свободны")


func test_single_tank_cannot_crack_an_evolved_nest() -> void:
	# Главное правило ветки: уровень гнезда — это число танков, которое должно
	# бить по нему одновременно. Меньше — техника гибнет впустую.
	var depot: TankDepot = build_depot(1)
	var nest: Nest = place(BuildingDefs.NEST, Vector2i(8, 0)) as Nest
	nest.level = 3
	nest.health = nest.max_health()
	var before: int = nest.health

	check_eq(combat.order_attack(world.buildings, nest.id), 1, "должен выехать один танк")
	run_ticks(200)
	check_eq(nest.health, before, "одиночке гнездо третьего уровня не по зубам")
	check(
		depot.tanks.is_empty() or depot.tanks[0].health < Tank.MAX_HEALTH,
		"гнездо должно огрызаться на приехавшего"
	)


func test_enough_tanks_destroy_the_nest() -> void:
	var depot: TankDepot = build_depot(3)
	var nest: Nest = place(BuildingDefs.NEST, Vector2i(8, 0)) as Nest
	nest.level = 2
	nest.health = nest.max_health()

	check_eq(combat.order_attack(world.buildings, nest.id), 3, "должны выехать все три")
	run_ticks(600)
	check_eq(
		world.buildings.get_building(nest.id), null,
		"колонны из трёх машин должно хватить на гнездо второго уровня"
	)


func test_tanks_come_home_when_the_nest_is_gone() -> void:
	var depot: TankDepot = build_depot(2)
	var nest: Nest = place(BuildingDefs.NEST, Vector2i(8, 0)) as Nest
	nest.level = 1
	nest.health = nest.max_health()
	combat.order_attack(world.buildings, nest.id)
	run_ticks(800)

	check_eq(world.buildings.get_building(nest.id), null, "гнездо должно пасть")
	var home: bool = false
	for tank: Tank in depot.tanks:
		if tank.state == Tank.State.IDLE:
			home = true
	check(home, "уцелевшая техника обязана вернуться в ангар")


func test_nests_grow_with_waves() -> void:
	var nest: Nest = place(BuildingDefs.NEST, Vector2i(20, 0)) as Nest
	check_eq(nest.required_tanks(), 1, "новое гнездо берётся одним танком")
	simulation.game_time = CombatSystem.GRACE_PERIOD + 1.0
	for i: int in Nest.WAVES_PER_LEVEL:
		combat.next_wave_at = simulation.game_time
		run_ticks(2)
		simulation.game_time += 1.0
	check(nest.level > 1, "после нескольких волн гнездо должно подрасти")
	check_eq(nest.required_tanks(), nest.level, "уровень и есть число нужных танков")


func test_nest_level_survives_save_and_load() -> void:
	var nest: Nest = place(BuildingDefs.NEST, Vector2i(20, 0)) as Nest
	nest.evolve()
	nest.evolve()
	var data: Array = world.buildings.serialize()

	var other_grid := Grid.new(world.grid.size)
	for i: int in other_grid.size * other_grid.size:
		other_grid.terrain[i] = TileTypes.Terrain.GRASS
	var other := BuildingRegistry.new(other_grid)
	other.deserialize(data)
	var restored: Nest = other.get_building(nest.id) as Nest
	check_eq(restored.level, nest.level, "уровень гнезда потерялся при загрузке")


func test_tanks_survive_save_and_load() -> void:
	var depot: TankDepot = build_depot(2)
	depot.tanks[0].health = 100
	var data: Array = world.buildings.serialize()

	var other_grid := Grid.new(world.grid.size)
	for i: int in other_grid.size * other_grid.size:
		other_grid.terrain[i] = TileTypes.Terrain.GRASS
	var other := BuildingRegistry.new(other_grid)
	other.deserialize(data)
	var restored: TankDepot = other.get_building(depot.id) as TankDepot
	check_eq(restored.tank_count(), 2, "танки потерялись при загрузке")
	check_eq(restored.tanks[0].health, 100, "повреждения техники не сохранились")


## --- Анимация и разрушения -------------------------------------------------

func test_turret_barrel_tracks_the_target() -> void:
	var turret: Turret = place(BuildingDefs.TURRET, Vector2i(0, 0)) as Turret
	turret.input.add(Items.AMMO, 40)
	place(BuildingDefs.SOLAR, Vector2i(0, 5))
	var monster := Monster.new()
	monster.id = 9
	monster.max_health = 900
	monster.health = 900
	# Цель строго снизу: ствол обязан развернуться примерно на 90 градусов.
	monster.position = turret.center() + Vector2(0.0, float(Constants.TILE_SIZE) * 4.0)
	monster.previous_position = monster.position
	combat.monsters.append(monster)

	run_ticks(1)
	check(
		absf(turret.aim_angle - PI * 0.5) < 0.2,
		"ствол должен смотреть на цель, а не в сторону: %.2f" % turret.aim_angle
	)
	check(turret.flash_left > 0.0, "после выстрела должна остаться вспышка")

	# Перезарядка обязана длиться ровно столько, сколько заявлено: когда её
	# уменьшали и здание, и боевая система, турель стреляла вдвое чаще.
	check(
		turret.reload_left > Turret.RELOAD_SECONDS * 0.7,
		"перезарядка утекает быстрее положенного: %.2f" % turret.reload_left
	)


func test_monsters_do_not_march_in_step() -> void:
	# Вся стая на одном кадре анимации выглядит строем, а не жуками.
	var first := Monster.new()
	first.id = 1
	var second := Monster.new()
	second.id = 2
	check_ne(
		MonsterRenderer.is_stepping(0.0, first),
		MonsterRenderer.is_stepping(0.0, second),
		"соседние жуки должны быть в противофазе"
	)


func test_attacking_monster_stops_stepping() -> void:
	var monster := Monster.new()
	monster.id = 1
	monster.state = Monster.State.ATTACKING
	for step: int in 10:
		check(
			not MonsterRenderer.is_stepping(float(step) * 0.1, monster),
			"вцепившийся жук не должен перебирать лапами"
		)
