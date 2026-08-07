class_name TilesetFactory
extends RefCounted

## Сборка TileSet из процедурного атласа.
##
## Один источник-атлас на все тайлы: поверхность и руда лежат в одной текстуре,
## поэтому оба слоя рисуются без переключения текстуры между вызовами.

const TERRAIN_SOURCE_ID: int = 0


static func build_terrain_tileset() -> TileSet:
	Art.build()

	var tile_size := Vector2i(Constants.TILE_SIZE, Constants.TILE_SIZE)
	var source := TileSetAtlasSource.new()
	source.texture = Art.terrain_texture
	source.texture_region_size = tile_size

	var grid_size: Vector2i = TerrainArt.atlas_size_in_tiles()
	for y: int in grid_size.y:
		for x: int in grid_size.x:
			source.create_tile(Vector2i(x, y))

	var tileset := TileSet.new()
	tileset.tile_size = tile_size
	tileset.add_source(source, TERRAIN_SOURCE_ID)
	return tileset
