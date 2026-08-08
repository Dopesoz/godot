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
