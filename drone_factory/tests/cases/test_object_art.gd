extends TestCase
## Атлас объектов собирается кодом, поэтому проверяем упаковку и содержимое:
## пустой или наложившийся спрайт заметить в игре гораздо труднее, чем тут.


func before_each() -> void:
	Art.build()


func test_every_building_has_a_sprite() -> void:
	for def_id: StringName in BuildingDefs.all_ids():
		check(Art.has_sprite(def_id), "нет спрайта здания %s" % def_id)
		var region: Rect2i = Art.region(def_id)
		var expected: Vector2i = BuildingDefs.size_of(def_id) * Constants.TILE_SIZE
		check_eq(region.size, expected, "размер спрайта %s не совпадает с размером здания" % def_id)


func test_every_item_has_an_icon() -> void:
	for item_id: StringName in Items.all_ids():
		check(Art.has_sprite(item_id), "нет иконки предмета %s" % item_id)
		check_eq(Art.region(item_id).size, Vector2i(ObjectArt.ICON_SIZE, ObjectArt.ICON_SIZE))


func test_service_sprites_exist() -> void:
	for key: StringName in [ObjectArt.DRONE, ObjectArt.SELECTION, ObjectArt.BADGE_NO_POWER,
			ObjectArt.BADGE_NO_INPUT, ObjectArt.BADGE_FULL, ObjectArt.BADGE_NO_ORE]:
		check(Art.has_sprite(key), "нет служебного спрайта %s" % key)


func test_regions_fit_inside_atlas() -> void:
	var size := Vector2i(Art.object_texture.get_width(), Art.object_texture.get_height())
	check_eq(size.x, Art.OBJECT_ATLAS_WIDTH, "ширина атласа должна быть фиксированной")
	for def_id: StringName in BuildingDefs.all_ids():
		var region: Rect2i = Art.region(def_id)
		check(region.end.x <= size.x and region.end.y <= size.y, "спрайт %s вышел за атлас" % def_id)


func test_regions_do_not_overlap() -> void:
	var keys: Array[StringName] = BuildingDefs.all_ids()
	for item_id: StringName in Items.all_ids():
		keys.append(item_id)
	keys.append(ObjectArt.DRONE)
	for i: int in keys.size():
		for j: int in range(i + 1, keys.size()):
			var a: Rect2i = Art.region(keys[i])
			var b: Rect2i = Art.region(keys[j])
			check(not a.intersects(b), "спрайты %s и %s наложились" % [keys[i], keys[j]])


func test_sprites_are_not_blank() -> void:
	var image: Image = Art.object_texture.get_image()
	var keys: Array[StringName] = BuildingDefs.all_ids()
	for item_id: StringName in Items.all_ids():
		keys.append(item_id)
	keys.append(ObjectArt.DRONE)
	for key: StringName in keys:
		var region: Rect2i = Art.region(key)
		var solid: int = 0
		for y: int in region.size.y:
			for x: int in region.size.x:
				if image.get_pixel(region.position.x + x, region.position.y + y).a > 0.0:
					solid += 1
		var fill: float = float(solid) / float(region.size.x * region.size.y)
		check(fill > 0.2, "спрайт %s почти пустой (заполнение %.2f)" % [key, fill])
		check(fill < 1.0, "спрайт %s не имеет прозрачных краёв" % key)


func test_icon_textures_are_cached() -> void:
	var first: AtlasTexture = Art.icon(Items.GEAR)
	var second: AtlasTexture = Art.icon(Items.GEAR)
	check_eq(first, second, "иконки должны кешироваться, а не создаваться заново")
	check_eq(first.atlas, Art.object_texture)
	check_eq(Vector2i(first.region.size), Art.region(Items.GEAR).size)


func test_atlas_is_small_enough_for_low_end_gpu() -> void:
	# Один небольшой атлас — это одна текстура в памяти и минимум переключений.
	check(Art.object_texture.get_height() <= 512, "атлас объектов вырос слишком сильно")
