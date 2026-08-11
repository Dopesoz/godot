class_name IsoUtils
extends RefCounted

## Isometric coordinate math. The single place in the project allowed to know
## how a grid cell maps to a pixel. Everything else calls these functions, so
## changing tile size or projection is a one-file change.
##
## Projection (2:1 diamond, cell (0,0) centred on the origin):
##
##       (0,0)
##      /     \        +x goes down-right
##  (0,1)     (1,0)    +y goes down-left
##      \     /
##       (1,1)


## Centre of a cell in world pixels.
static func cell_to_world(cell: Vector2i, floor_index: int = 0) -> Vector2:
	return Vector2(
		(cell.x - cell.y) * GameConstants.TILE_HW,
		(cell.x + cell.y) * GameConstants.TILE_HH - floor_index * GameConstants.WALL_HEIGHT
	)


## Same as cell_to_world but accepts fractional cell positions, which is what a
## walking citizen has.
static func cell_to_world_f(pos: Vector2, floor_index: int = 0) -> Vector2:
	return Vector2(
		(pos.x - pos.y) * GameConstants.TILE_HW,
		(pos.x + pos.y) * GameConstants.TILE_HH - floor_index * GameConstants.WALL_HEIGHT
	)


## Inverse projection: which cell does this world pixel fall into.
static func world_to_cell(world: Vector2, floor_index: int = 0) -> Vector2i:
	var p := world_to_cell_f(world, floor_index)
	return Vector2i(floori(p.x), floori(p.y))


## Fractional cell coordinates of a world pixel. The .5 offsets undo the
## cell-centre convention used by cell_to_world.
static func world_to_cell_f(world: Vector2, floor_index: int = 0) -> Vector2:
	var y := world.y + floor_index * GameConstants.WALL_HEIGHT
	var a := world.x / GameConstants.TILE_HW
	var b := y / GameConstants.TILE_HH
	return Vector2((b + a) * 0.5 + 0.5, (b - a) * 0.5 + 0.5)


## The four corners of a cell's diamond, in world pixels, clockwise from top.
## Used for drawing the grid and for hit-testing.
static func cell_polygon(cell: Vector2i, floor_index: int = 0) -> PackedVector2Array:
	var c := cell_to_world(cell, floor_index)
	return PackedVector2Array([
		c + Vector2(0.0, -GameConstants.TILE_HH),
		c + Vector2(GameConstants.TILE_HW, 0.0),
		c + Vector2(0.0, GameConstants.TILE_HH),
		c + Vector2(-GameConstants.TILE_HW, 0.0),
	])


## Draw order key. Godot's built-in Y-sort works on world Y, which is already
## correct for this projection, but sprites that span several cells need this
## explicit value.
static func depth(cell: Vector2i, floor_index: int = 0) -> float:
	return float(cell.x + cell.y) + float(floor_index) * 1000.0


## The four orthogonal neighbours of a cell, in N/E/S/W order. Diagonals are
## deliberately excluded: a citizen must never cut a wall corner.
static func neighbors(cell: Vector2i) -> Array[Vector2i]:
	return [
		cell + Vector2i(0, -1),
		cell + Vector2i(1, 0),
		cell + Vector2i(0, 1),
		cell + Vector2i(-1, 0),
	]


## The two endpoints, in world pixels, of a canonical cell edge (see WorldGrid).
## A horizontal edge is the top-right side of its cell's diamond, a vertical
## edge the top-left side. Walls, doors, windows and their previews all stand on
## this segment, so the geometry lives here rather than in each renderer.
static func edge_segment(edge: Vector3i, floor_index: int = 0) -> PackedVector2Array:
	var center := cell_to_world(Vector2i(edge.x, edge.y), floor_index)
	var top := center + Vector2(0.0, -GameConstants.TILE_HH)
	if edge.z == GameEnums.EdgeAxis.HORIZONTAL:
		return PackedVector2Array([top, center + Vector2(GameConstants.TILE_HW, 0.0)])
	return PackedVector2Array([center + Vector2(-GameConstants.TILE_HW, 0.0), top])


## Manhattan distance, the correct metric for 4-way movement.
static func cell_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## Every cell inside an inclusive rectangle. Used by drag-to-build.
static func cells_in_rect(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var x0 := mini(from.x, to.x)
	var x1 := maxi(from.x, to.x)
	var y0 := mini(from.y, to.y)
	var y1 := maxi(from.y, to.y)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			result.append(Vector2i(x, y))
	return result
