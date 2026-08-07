class_name TileTypes
extends RefCounted

## Описание типов клеток мира: поверхность и залежи руды.
## Индексы enum пишутся в сохранение, поэтому порядок менять нельзя —
## только дописывать в конец.

enum Terrain {
	GRASS,
	DIRT,
	SAND,
	ROCK,
	WATER,
}

enum Ore {
	NONE,
	STONE,
	IRON,
	COPPER,
}

const TERRAIN_COUNT: int = 5
const ORE_COUNT: int = 4

## Сколько вариантов одного тайла рисуется, чтобы поверхность не «тайлилась» узором.
const VARIANTS: int = 4

const TERRAIN_NAMES: Dictionary[int, String] = {
	Terrain.GRASS: "Трава",
	Terrain.DIRT: "Земля",
	Terrain.SAND: "Песок",
	Terrain.ROCK: "Скала",
	Terrain.WATER: "Вода",
}

const ORE_NAMES: Dictionary[int, String] = {
	Ore.NONE: "—",
	Ore.STONE: "Камень",
	Ore.IRON: "Железная руда",
	Ore.COPPER: "Медная руда",
}


## Можно ли ставить здания на такую поверхность.
static func is_buildable(terrain: int) -> bool:
	return terrain != Terrain.WATER and terrain != Terrain.ROCK


## Проходима ли клетка для наземных объектов (дроны летают и игнорируют это).
static func is_passable(terrain: int) -> bool:
	return terrain != Terrain.WATER and terrain != Terrain.ROCK


static func terrain_name(terrain: int) -> String:
	return TERRAIN_NAMES.get(terrain, "?")


static func ore_name(ore: int) -> String:
	return ORE_NAMES.get(ore, "?")
