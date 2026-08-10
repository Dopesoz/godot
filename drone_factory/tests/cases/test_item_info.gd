extends TestCase
## Справка по предмету: где берут, куда идёт, сколько осталось в земле.

var world: GameWorld = null


func before_each() -> void:
	world = GameWorld.new()
	Engine.get_main_loop().root.add_child(world)
	world.new_game(3535)
	ItemInfo.forget_reserves()


func after_each() -> void:
	if is_instance_valid(world):
		world.free()
	world = null
	ItemInfo.forget_reserves()


func test_every_item_has_somewhere_to_go() -> void:
	# Предмет, который негде применить, — это либо забытая ветка, либо мусор
	# в каталоге. И то и другое игрок увидит как «зачем мне это?».
	for item_id: StringName in Items.all_ids():
		var uses: int = (
			ItemInfo.used_in(item_id).size()
			+ ItemInfo.builds(item_id).size()
			+ ItemInfo.researches(item_id).size()
			+ ItemInfo.consumed_by(item_id).size()
			+ (1 if ItemInfo.tradable(item_id) else 0)
		)
		check(uses > 0, "предмету %s некуда деваться" % item_id)


func test_uses_are_correct_for_a_known_item() -> void:
	check(
		ItemInfo.used_in(Items.WIRE).has(Recipes.CRAFT_CIRCUIT),
		"провод должен идти в микросхемы"
	)
	check(
		ItemInfo.builds(Items.BRICK).has(BuildingDefs.BOILER),
		"кирпич должен числиться в стоимости котла"
	)
	check(
		ItemInfo.researches(Items.SCIENCE_RED).has(Technologies.ELECTRONICS),
		"красные колбы тратятся на электронику"
	)
	check(
		ItemInfo.consumed_by(Items.AMMO).has(BuildingDefs.TURRET),
		"патроны должна съедать турель"
	)
	check(
		ItemInfo.consumed_by(Items.WOOD).has(BuildingDefs.PORTER_HUT),
		"дерево должно числиться топливом хижины"
	)
	check(ItemInfo.tradable(Items.DIAMOND), "алмазы обмениваются на науку")
	check(not ItemInfo.tradable(Items.STONE), "камень на науку не меняют")


func test_reserves_are_counted_for_ores_only() -> void:
	var iron: int = ItemInfo.reserves(world.grid, Items.IRON_ORE)
	check(iron > 0, "железо должно быть в земле")
	check_eq(
		ItemInfo.reserves(world.grid, Items.CIRCUIT), -1,
		"у крафтового предмета запасов в земле быть не может"
	)


func test_reserves_shrink_when_ore_is_mined() -> void:
	var before: int = ItemInfo.reserves(world.grid, Items.IRON_ORE)
	check(before > 0, "нужна руда для проверки")

	# Вычищаем всё железо и просим пересчитать: кеш не должен врать вечно.
	for i: int in world.grid.size * world.grid.size:
		if world.grid.ore[i] == TileTypes.Ore.IRON:
			world.grid.ore[i] = TileTypes.Ore.NONE
			world.grid.ore_amount[i] = 0
	ItemInfo.forget_reserves()
	check_eq(
		ItemInfo.reserves(world.grid, Items.IRON_ORE), 0,
		"после выработки запасов должно остаться ноль"
	)


func test_reserve_scan_is_fast_enough_for_a_phone() -> void:
	ItemInfo.forget_reserves()
	var start_usec: int = Time.get_ticks_usec()
	ItemInfo.reserves(world.grid, Items.IRON_ORE)
	var elapsed_ms: float = float(Time.get_ticks_usec() - start_usec) / 1000.0
	check(elapsed_ms < 60.0, "подсчёт запасов занял %.1f мс" % elapsed_ms)

	# Повторный запрос обязан идти из кеша, а не сканировать карту заново.
	start_usec = Time.get_ticks_usec()
	ItemInfo.reserves(world.grid, Items.COPPER_ORE)
	var cached_ms: float = float(Time.get_ticks_usec() - start_usec) / 1000.0
	check(cached_ms < elapsed_ms * 0.5 + 1.0, "повторный запрос не должен сканировать карту")
