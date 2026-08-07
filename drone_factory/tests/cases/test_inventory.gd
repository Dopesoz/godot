extends TestCase
## Инвентарь трогают все системы сразу, поэтому его инварианты проверяем плотно:
## сумма всегда сходится, частичный приём честный, списание атомарно.

var inv: Inventory


func before_each() -> void:
	inv = Inventory.new(100)


func test_add_and_count() -> void:
	check_eq(inv.add(Items.IRON_ORE, 30), 30)
	check_eq(inv.count(Items.IRON_ORE), 30)
	check_eq(inv.total(), 30)
	check_eq(inv.free_space(), 70)
	check(not inv.is_empty())
	check(not inv.is_full())


func test_partial_accept_when_full() -> void:
	inv.add(Items.STONE, 90)
	check_eq(inv.add(Items.IRON_ORE, 30), 10, "должно принять только остаток")
	check(inv.is_full())
	check_eq(inv.add(Items.IRON_ORE, 5), 0, "в полный инвентарь ничего не влезает")
	check_eq(inv.total(), 100, "переполнение недопустимо")


func test_remove_more_than_present() -> void:
	inv.add(Items.STONE, 10)
	check_eq(inv.remove(Items.STONE, 25), 10, "нельзя забрать больше, чем есть")
	check_eq(inv.count(Items.STONE), 0)
	check_eq(inv.total(), 0)
	check(not inv.item_ids().has(Items.STONE), "опустевший предмет не должен оставаться в списке")


func test_negative_and_zero_amounts_are_ignored() -> void:
	check_eq(inv.add(Items.STONE, 0), 0)
	check_eq(inv.add(Items.STONE, -5), 0)
	check_eq(inv.remove(Items.STONE, -5), 0)
	check_eq(inv.total(), 0)


func test_filter_blocks_foreign_items() -> void:
	inv.filter = [Items.IRON_ORE]
	check_eq(inv.add(Items.IRON_ORE, 10), 10)
	check_eq(inv.add(Items.COPPER_ORE, 10), 0, "фильтр должен отсекать чужие предметы")
	check_eq(inv.space_for(Items.COPPER_ORE), 0)
	check(inv.space_for(Items.IRON_ORE) > 0)


func test_consume_all_is_atomic() -> void:
	inv.add(Items.WIRE, 2)
	inv.add(Items.IRON_PLATE, 5)
	var recipe: Dictionary = Recipes.inputs(Recipes.CRAFT_CIRCUIT)

	check(not inv.consume_all(recipe), "неполный набор не должен списываться")
	check_eq(inv.count(Items.WIRE), 2, "провод не должен пропасть при неудаче")
	check_eq(inv.count(Items.IRON_PLATE), 5)

	inv.add(Items.WIRE, 1)
	check(inv.consume_all(recipe), "полный набор должен списаться")
	check_eq(inv.count(Items.WIRE), 0)
	check_eq(inv.count(Items.IRON_PLATE), 4)


func test_fits_and_add_all() -> void:
	var small := Inventory.new(3)
	check(not small.fits_all({Items.GEAR: 2, Items.WIRE: 2}), "набор больше ёмкости")
	check(small.fits_all({Items.GEAR: 2, Items.WIRE: 1}))
	check(small.add_all({Items.GEAR: 2, Items.WIRE: 1}))
	check_eq(small.total(), 3)
	check(not small.add_all({Items.GEAR: 1}), "в полный инвентарь набор не кладётся")


func test_has_all() -> void:
	inv.add(Items.GEAR, 2)
	inv.add(Items.COPPER_PLATE, 1)
	check(inv.has_all(Recipes.inputs(Recipes.CRAFT_SCIENCE_RED)))
	check(not inv.has_all(Recipes.inputs(Recipes.CRAFT_DRONE)))


func test_serialization_round_trip() -> void:
	inv.add(Items.IRON_PLATE, 12)
	inv.add(Items.GEAR, 7)
	var restored := Inventory.new(100)
	restored.deserialize(inv.serialize())
	check_eq(restored.count(Items.IRON_PLATE), 12)
	check_eq(restored.count(Items.GEAR), 7)
	check_eq(restored.total(), 19)


func test_deserialize_skips_unknown_items() -> void:
	# Сохранение из старой версии не должно ронять новую сборку.
	var restored := Inventory.new(100)
	restored.deserialize({"iron_plate": 5, "obsolete_thing": 99})
	check_eq(restored.count(Items.IRON_PLATE), 5)
	check_eq(restored.total(), 5, "неизвестный предмет должен быть отброшен")


func test_totals_stay_consistent_under_random_operations() -> void:
	# Стресс-проверка инварианта: сумма по предметам всегда равна total().
	var ids: Array[StringName] = [Items.STONE, Items.IRON_ORE, Items.GEAR]
	var rng: RandomNumberGenerator = Rng.stream(7)
	for i: int in 500:
		var id: StringName = ids[rng.randi() % ids.size()]
		if rng.randf() < 0.5:
			inv.add(id, rng.randi_range(1, 30))
		else:
			inv.remove(id, rng.randi_range(1, 30))
	var sum: int = 0
	for id: StringName in inv.item_ids():
		sum += inv.count(id)
	check_eq(sum, inv.total(), "сумма по предметам разошлась с total()")
	check(inv.total() <= inv.capacity, "ёмкость превышена")
	check(inv.total() >= 0, "отрицательный остаток")
