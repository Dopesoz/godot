extends TestCase
## Каталоги — данные, и ошибка в них проявится только в игре. Проверяем их
## целостность автоматически: каждый предмет достижим, каждый рецепт корректен.


func test_item_defs_are_complete() -> void:
	for id: StringName in Items.all_ids():
		var def: Dictionary = Items.DEFS[id]
		check(def.has("name") and not String(def["name"]).is_empty(), "нет названия: %s" % id)
		check(def.has("shape"), "нет формы иконки: %s" % id)
		check(def.has("color") and def.has("accent"), "нет цветов: %s" % id)
		check(Items.stack_size(id) > 0, "нулевой стек: %s" % id)


func test_unknown_item_is_handled_gracefully() -> void:
	check(not Items.exists(&"nope"))
	check_eq(Items.display_name(&"nope"), "nope", "неизвестный предмет не должен ронять UI")
	check(Items.stack_size(&"nope") > 0)


func test_ore_mapping_covers_all_ore_types() -> void:
	for ore_type: int in [TileTypes.Ore.STONE, TileTypes.Ore.IRON, TileTypes.Ore.COPPER]:
		var item: StringName = Items.from_ore(ore_type)
		check(Items.exists(item), "руда %d не даёт предмета" % ore_type)
	check_eq(Items.from_ore(TileTypes.Ore.NONE), &"", "пустая клетка не даёт предмета")


func test_recipes_reference_existing_items() -> void:
	for id: StringName in Recipes.DEFS:
		for item: StringName in Recipes.inputs(id):
			check(Items.exists(item), "рецепт %s требует несуществующий %s" % [id, item])
			check(int(Recipes.inputs(id)[item]) > 0, "неположительный вход в %s" % id)
		for item: StringName in Recipes.outputs(id):
			check(Items.exists(item), "рецепт %s выдаёт несуществующий %s" % [id, item])
			check(int(Recipes.outputs(id)[item]) > 0, "неположительный выход в %s" % id)


func test_recipes_are_well_formed() -> void:
	for id: StringName in Recipes.DEFS:
		check(Recipes.craft_time(id) > 0.0, "нулевое время у рецепта %s" % id)
		check(not Recipes.outputs(id).is_empty(), "рецепт %s ничего не производит" % id)
		check(
			Recipes.machine(id) in Recipes.Machine.values(),
			"неизвестная машина у рецепта %s" % id
		)
		# Рецепт, который потребляет свой же продукт, зациклит производство.
		for item: StringName in Recipes.outputs(id):
			check(not Recipes.inputs(id).has(item), "рецепт %s зациклен на %s" % [id, item])


func test_every_item_is_obtainable() -> void:
	# Предмет либо добывается буром, либо производится зданием напрямую
	# (вода из водозабора), либо является выходом рецепта. Иначе он мусор
	# в каталоге или недостижимая цель для игрока.
	var minable: Array[StringName] = []
	for ore_type: int in Items.ORE_TO_ITEM:
		minable.append(Items.ORE_TO_ITEM[ore_type])
	for id: StringName in Items.all_ids():
		var from_building: StringName = Items.source_building(id)
		var obtainable: bool = (
			minable.has(id)
			or Recipes.producing(id) != &""
			or (from_building != &"" and BuildingDefs.exists(from_building))
		)
		check(obtainable, "предмет %s нельзя получить никаким способом" % id)


func test_recipe_chains_terminate_at_ores() -> void:
	# Разворачиваем дерево рецептов до сырья: цикл или тупик означают,
	# что игрок упрётся в невыполнимую цель.
	for id: StringName in Recipes.DEFS:
		check(_resolves_to_ore(id, 0), "рецепт %s не сводится к добываемому сырью" % id)


func test_machines_have_recipes() -> void:
	check(not Recipes.for_machine(Recipes.Machine.FURNACE).is_empty(), "печи нечего плавить")
	check(not Recipes.for_machine(Recipes.Machine.ASSEMBLER).is_empty(), "сборщику нечего собирать")


func _resolves_to_ore(recipe_id: StringName, depth: int) -> bool:
	if depth > 8:
		return false
	var minable: Array[StringName] = []
	for ore_type: int in Items.ORE_TO_ITEM:
		minable.append(Items.ORE_TO_ITEM[ore_type])
	for item: StringName in Recipes.inputs(recipe_id):
		if minable.has(item) or Items.source_building(item) != &"":
			continue
		var source: StringName = Recipes.producing(item)
		if source == &"" or not _resolves_to_ore(source, depth + 1):
			return false
	return true


func test_every_build_material_is_obtainable() -> void:
	# Здание, в цене которого есть предмет ниоткуда, — это тупик в развитии.
	for def_id: StringName in BuildingDefs.all_ids():
		for item_id: StringName in BuildingDefs.cost(def_id):
			check(
				not Items.source_of(item_id).is_empty(),
				"%s стоит %s, но взять его негде" % [def_id, item_id]
			)


func test_every_item_says_where_it_comes_from() -> void:
	for item_id: StringName in Items.all_ids():
		check(
			not Items.source_of(item_id).is_empty(),
			"непонятно, где брать %s" % item_id
		)
