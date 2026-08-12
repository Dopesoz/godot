class_name Art
extends RefCounted

## Where a sprite comes from, and where on the map it goes.
##
## Everything the world draws is looked up here by id, so Painters never
## contains a file path and no scene holds a texture reference. Two rules make
## that work:
##
## 1. **Convention over configuration.** A furniture template with id `sofa` is
##    drawn with `assets/sprites/furniture/sofa.svg`, and `sofa_r.svg` when it
##    stands rotated a quarter turn. Adding an object to the game stays what it
##    was — one `.tres` — plus its two sprites, with nothing to wire up.
## 2. **A missing sprite is not an error.** Every lookup may return null, and
##    Painters falls back to the coloured block it drew before (design doc §28).
##    The game therefore still runs with no art at all, which is how it was
##    built and how a new object starts life.
##
## The sprites are authored at twice their in-game size (SPRITE_SCALE) so they
## stay sharp when the player zooms in, and are always drawn into an explicit
## rectangle derived from the grid — never at their raw pixel size.

const SPRITE_SCALE := 2.0

const FLOOR_DIR := "res://assets/sprites/floors/"
const WALL_DIR := "res://assets/sprites/walls/"
const FURNITURE_DIR := "res://assets/sprites/furniture/"
const VEHICLE_DIR := "res://assets/sprites/vehicles/"

## How many car liveries there are. Cars pick one by id and keep it.
const CAR_COLORS := 6

## Where the glass sits inside a window sprite, as fractions of the wall quad.
## Kept in step with PANE_X / PANE_Z in tools/make_sprites.py: the night glow is
## drawn over the sprite and has to land exactly on the pane.
const PANE_X := Vector2(0.22, 0.78)
const PANE_Z := Vector2(0.42, 1.16)
## Height of a wall sprite in the generator's units, where 1.0 == one cell.
const WALL_UNITS := 1.5

static var _cache: Dictionary = {}


## How many grass tiles there are to choose between.
const GRASS_VARIANTS := 3


## Ground under everything that has no floor material. Which of the variants a
## cell gets is a hash of its coordinates: stable across redraws and saves,
## with nothing stored per cell.
static func grass(cell: Vector2i) -> Texture2D:
	var pick := absi(cell.x * 73856093 ^ cell.y * 19349663) % GRASS_VARIANTS
	return _texture(FLOOR_DIR + "ground_grass_%d.svg" % pick)


## Which asphalt tile a road cell gets: the markings have to run along the
## street, and only the neighbours know which way that is. `kind` is one of
## "x", "y", "junction", "plain".
static func road_texture(kind: String) -> Texture2D:
	return _texture(FLOOR_DIR + "road_" + kind + ".svg")


## A car, seen coming towards the camera or going away from it, on either grid
## axis. Four sprites out of two drawings: mirroring screen x swaps the axes.
static func car_texture(color_index: int, coming: bool, along_x: bool) -> Texture2D:
	var stem := "car_%s_%d" % ["front" if coming else "back", absi(color_index) % CAR_COLORS]
	return _texture(VEHICLE_DIR + stem + ("" if along_x else "_r") + ".svg")


static func floor_texture(id: StringName) -> Texture2D:
	if id == &"":
		return null
	return _texture(FLOOR_DIR + String(id) + ".svg")


## `type` is a GameEnums.EdgeType, `axis` a GameEnums.EdgeAxis. Horizontal edges
## face the lit side of the world and vertical ones face away, so they are two
## different sprites rather than one mirrored at runtime.
static func wall_texture(type: int, axis: int) -> Texture2D:
	var stem := ""
	match type:
		GameEnums.EdgeType.WALL:
			stem = "wall"
		GameEnums.EdgeType.DOOR:
			stem = "door"
		GameEnums.EdgeType.WINDOW:
			stem = "window"
		_:
			return null
	var suffix := "_h" if axis == GameEnums.EdgeAxis.HORIZONTAL else "_v"
	return _texture(WALL_DIR + stem + suffix + ".svg")


## `quarter_turned` is true for rotation steps 1 and 3, where the footprint has
## swapped its axes — which in this projection is exactly a mirrored sprite.
static func furniture_texture(id: StringName, quarter_turned: bool) -> Texture2D:
	if id == &"":
		return null
	return _texture(FURNITURE_DIR + String(id) + ("_r" if quarter_turned else "") + ".svg")


# --- placement --------------------------------------------------------------

## Texture coordinates for a cell's diamond, in the order IsoUtils.cell_polygon
## returns its corners: top, right, bottom, left.
##
## A floor is drawn as a textured polygon rather than a sprite. The cell's
## diamond is a parallelogram, so the square texture maps onto it without
## distortion, the u axis becoming the world's +x; and because neighbouring
## cells share their edge vertices exactly, there is no seam between them. A
## diamond-shaped sprite has an antialiased border instead, and the whole map
## picks up a lattice of half-covered pixels.
## (A `static var` rather than a `const`: a packed array is not a constant
## expression in GDScript.)
static var TILE_UVS := PackedVector2Array([
	Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0),
])


## The rectangle a wall sprite covers: the quad its edge extrudes upwards.
## A horizontal edge runs down-right from the cell's top corner, a vertical one
## down-left, so the two rectangles sit on opposite sides of that corner.
static func wall_rect(edge: Vector3i, floor_index: int = 0) -> Rect2:
	var centre := IsoUtils.cell_to_world(Vector2i(edge.x, edge.y), floor_index)
	var top := centre + Vector2(0.0, -GameConstants.TILE_HH)
	var size := Vector2(GameConstants.TILE_HW, GameConstants.TILE_HH + GameConstants.WALL_HEIGHT)
	var left := top.x if edge.z == GameEnums.EdgeAxis.HORIZONTAL else top.x - GameConstants.TILE_HW
	return Rect2(Vector2(left, top.y - GameConstants.WALL_HEIGHT), size)


## The rectangle a furniture sprite covers.
##
## Width comes from the footprint alone — a w-by-d object is always
## (w + d) half-tiles wide on screen — and height from the sprite, because only
## the sprite knows how tall the object is. The bottom edge of the sprite is
## pinned to the bottom corner of the footprint, which is why no object needs a
## hand-tuned offset.
static func furniture_rect(origin: Vector2i, size: Vector2i, texture: Texture2D,
		floor_index: int = 0) -> Rect2:
	var centre := IsoUtils.cell_to_world(origin, floor_index)
	var width := float(size.x + size.y) * GameConstants.TILE_HW
	var height := float(texture.get_height()) / SPRITE_SCALE
	var bottom := centre.y + float(size.x + size.y) * GameConstants.TILE_HH - GameConstants.TILE_HH
	return Rect2(Vector2(centre.x - float(size.y) * GameConstants.TILE_HW, bottom - height),
			Vector2(width, height))


## A point on a wall's face, in the same units the sprite was drawn in:
## `along` runs 0..1 from the cell's top corner along the edge, `up` runs
## 0..WALL_UNITS from the floor. Used to put the night glow exactly on the pane.
static func wall_point(edge: Vector3i, along: float, up: float, floor_index: int = 0) -> Vector2:
	var centre := IsoUtils.cell_to_world(Vector2i(edge.x, edge.y), floor_index)
	var top := centre + Vector2(0.0, -GameConstants.TILE_HH)
	var direction := Vector2(GameConstants.TILE_HW, GameConstants.TILE_HH)
	if edge.z != GameEnums.EdgeAxis.HORIZONTAL:
		direction.x = -direction.x
	var per_unit := float(GameConstants.WALL_HEIGHT) / WALL_UNITS
	return top + direction * along - Vector2(0.0, up * per_unit)


## The diamond a footprint covers on the ground, optionally grown by `expand`
## cells. Used for the pool of light under a piece of furniture in use.
static func footprint_polygon(origin: Vector2i, size: Vector2i, floor_index: int = 0,
		expand: float = 0.0) -> PackedVector2Array:
	var centre := IsoUtils.cell_to_world(origin, floor_index) - Vector2(0.0, GameConstants.TILE_HH)
	var w := float(size.x)
	var h := float(size.y)
	var points := [
		Vector2(-expand, -expand),
		Vector2(w + expand, -expand),
		Vector2(w + expand, h + expand),
		Vector2(-expand, h + expand),
	]
	var polygon := PackedVector2Array()
	for p: Vector2 in points:
		polygon.append(centre + Vector2((p.x - p.y) * GameConstants.TILE_HW,
				(p.x + p.y) * GameConstants.TILE_HH))
	return polygon


static func _texture(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	# Cached even when missing: a lookup happens per object per redraw, and a
	# failed load must not be retried on every frame.
	_cache[path] = texture
	return texture
