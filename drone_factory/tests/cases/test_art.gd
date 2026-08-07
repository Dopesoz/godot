extends TestCase
## Графика генерируется кодом, значит её тоже нужно проверять автоматически.


func before_each() -> void:
	Art.build()


func test_atlas_dimensions() -> void:
	var tiles: Vector2i = TerrainArt.atlas_size_in_tiles()
	check_eq(Art.terrain_texture.get_width(), tiles.x * Constants.TILE_SIZE)
	check_eq(Art.terrain_texture.get_height(), tiles.y * Constants.TILE_SIZE)


func test_terrain_tiles_are_opaque() -> void:
	# Поверхность — нижний слой, дыр в ней быть не должно.
	var image: Image = Art.terrain_texture.get_image()
	for terrain: int in TileTypes.TERRAIN_COUNT:
		for variant: int in TileTypes.VARIANTS:
			var coords: Vector2i = Art.terrain_tile(terrain, variant)
			var opaque: bool = true
			for y: int in Constants.TILE_SIZE:
				for x: int in Constants.TILE_SIZE:
					var px: Color = image.get_pixel(
						coords.x * Constants.TILE_SIZE + x,
						coords.y * Constants.TILE_SIZE + y
					)
					if px.a < 1.0:
						opaque = false
			check(opaque, "тайл поверхности %d/%d полупрозрачен" % [terrain, variant])


func test_ore_overlay_has_transparency() -> void:
	# Руда — наложение: земля обязана просвечивать.
	var image: Image = Art.terrain_texture.get_image()
	for ore: int in [TileTypes.Ore.STONE, TileTypes.Ore.IRON, TileTypes.Ore.COPPER]:
		var coords: Vector2i = Art.ore_tile(ore, 0)
		var solid: int = 0
		var clear: int = 0
		for y: int in Constants.TILE_SIZE:
			for x: int in Constants.TILE_SIZE:
				var px: Color = image.get_pixel(
					coords.x * Constants.TILE_SIZE + x,
					coords.y * Constants.TILE_SIZE + y
				)
				if px.a > 0.0:
					solid += 1
				else:
					clear += 1
		check(solid > 8, "руда %d почти не видна (%d пикселей)" % [ore, solid])
		check(clear > 8, "руда %d закрывает всю клетку" % ore)


func test_empty_ore_tile_is_blank() -> void:
	var image: Image = Art.terrain_texture.get_image()
	var coords: Vector2i = Art.ore_tile(TileTypes.Ore.NONE, 0)
	for y: int in Constants.TILE_SIZE:
		for x: int in Constants.TILE_SIZE:
			var px: Color = image.get_pixel(
				coords.x * Constants.TILE_SIZE + x,
				coords.y * Constants.TILE_SIZE + y
			)
			check_eq(px.a, 0.0, "пустая руда должна быть прозрачной")


func test_variant_is_stable_and_in_range() -> void:
	for i: int in 100:
		var cell := Vector2i(i * 3 - 40, i * 7)
		var v: int = Art.variant_for(cell)
		check(v >= 0 and v < TileTypes.VARIANTS, "вариант вне диапазона: %d" % v)
		check_eq(Art.variant_for(cell), v, "вариант должен быть стабильным")


func test_canvas_outline_and_mirror() -> void:
	var canvas := PixelCanvas.new(8, 8)
	canvas.rect(3, 3, 2, 2, Palette.ACCENT)
	canvas.outline(Palette.OUTLINE)
	check_eq(canvas.image.get_pixel(2, 3), Palette.OUTLINE, "обводка слева")
	check_eq(canvas.image.get_pixel(3, 3), Palette.ACCENT, "заливка не должна затираться")

	var mirrored := PixelCanvas.new(8, 4)
	mirrored.put(0, 0, Palette.OK)
	mirrored.mirror_horizontal()
	check_eq(mirrored.image.get_pixel(7, 0), Palette.OK, "зеркалирование по горизонтали")
