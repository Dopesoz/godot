extends Node2D

## Draws the ground: one isometric diamond per cell.
##
## Placeholder art per design doc §28 — flat colours, no textures. What matters
## now is that the projection, the draw order and the redraw triggers are right;
## swapping `draw_colored_polygon` for a sprite later changes this file only.
##
## Performance note: Godot caches the commands issued in `_draw`, so a 40x40 map
## costs 1600 polygons once, not per frame. Around Phase 9 (a much bigger city)
## this gets replaced by chunked layers that only redraw the chunk that changed;
## the redraw triggers below are already per-cell for that reason.

const GRASS_A := Color(0.36, 0.52, 0.31)
const GRASS_B := Color(0.33, 0.49, 0.29)
const FLOOR_FALLBACK := Color(0.62, 0.51, 0.38)
const EDGE_COLOR := Color(0.0, 0.0, 0.0, 0.10)
## Base colour of the grass sprite. The flat diamond is painted underneath the
## texture so the two blend at the tile's antialiased border — without it, every
## cell edge shows as a hairline seam.
const GRASS_BASE := Color(0.349, 0.498, 0.271)

var _grid: WorldGrid
## Cached template lookups: _draw touches every floored cell, and a missing id
## would otherwise log a warning on every redraw.
var _floor_cache: Dictionary = {}


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	EventBus.world_ready.connect(_on_world_ready)
	EventBus.cell_changed.connect(_on_cell_changed)


func _on_world_ready(world: WorldGrid) -> void:
	_grid = world
	queue_redraw()


func _on_cell_changed(_cell: Vector2i, _floor_index: int) -> void:
	queue_redraw()


func _draw() -> void:
	if _grid == null:
		return
	for y in _grid.size.y:
		for x in _grid.size.x:
			var cell := Vector2i(x, y)
			var polygon := IsoUtils.cell_polygon(cell)
			var material := _material_at(cell)
			var texture: Texture2D
			if material == null:
				texture = Art.grass(cell)
			elif material.is_road:
				texture = Art.road_texture(_road_kind(cell))
			else:
				texture = Art.floor_texture(material.id)
			if texture != null:
				# The polygon is the tile. Neighbouring cells share their edge
				# vertices exactly, so there is nothing to seam — see the Tile
				# class in tools/isolib.py for why this is not a sprite.
				draw_colored_polygon(polygon, Color.WHITE, Art.TILE_UVS, texture)
			else:
				draw_colored_polygon(polygon, _color_for(cell, material))
				# Only the untextured checkerboard needs the outline to keep
				# individual cells readable.
				if material == null:
					draw_polyline(polygon + PackedVector2Array([polygon[0]]), EDGE_COLOR, 1.0)


## A road tile is chosen by what its neighbours are, so a junction looks like a
## junction and a straight stretch has its dashes pointing the right way.
func _road_kind(cell: Vector2i) -> String:
	var along_x := _is_road(cell + Vector2i(1, 0)) or _is_road(cell + Vector2i(-1, 0))
	var along_y := _is_road(cell + Vector2i(0, 1)) or _is_road(cell + Vector2i(0, -1))
	if along_x and along_y:
		return "junction"
	if along_x:
		return "x"
	if along_y:
		return "y"
	return "plain"


func _is_road(cell: Vector2i) -> bool:
	var material := _material_at(cell)
	return material != null and material.is_road


func _material_at(cell: Vector2i) -> FloorData:
	var data := _grid.get_cell(cell)
	if data == null or data.floor_id == &"":
		return null
	if not _floor_cache.has(data.floor_id):
		_floor_cache[data.floor_id] = Database.get_floor(data.floor_id)
	return _floor_cache[data.floor_id]


func _color_for(cell: Vector2i, material: FloorData) -> Color:
	if material != null:
		return material.placeholder_color
	# Checkerboard so individual cells stay readable without a grid overlay.
	return GRASS_A if (cell.x + cell.y) % 2 == 0 else GRASS_B
