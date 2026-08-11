class_name Furniture
extends RefCounted

## One physical object standing in the world: *this* bed, in *this* bedroom.
##
## The template (FurnitureData) says what a bed is; this says where it is, which
## way it faces and who is using it right now. Only the template id is written to
## the save file, so re-balancing a bed later changes every bed in every save.

var id: int = -1
var data_id: StringName = &""
## Top-left cell of the footprint.
var origin: Vector2i = Vector2i.ZERO
## 0..3, each step is 90 degrees. Swaps the footprint on odd steps.
var rotation_steps: int = 0
var floor_index: int = 0
## Room this object belongs to, -1 when standing outdoors. Maintained by the
## registry whenever rooms are rebuilt.
var room_id: int = -1
## Citizen ids currently interacting with it, capped by InteractionData.capacity.
var users: Array[int] = []

var _data: FurnitureData


func data() -> FurnitureData:
	if _data == null:
		_data = Database.get_furniture(data_id)
	return _data


func size() -> Vector2i:
	var template := data()
	return template.rotated_size(rotation_steps) if template != null else Vector2i.ONE


## Every cell this object stands on.
func cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var extent := size()
	for y in extent.y:
		for x in extent.x:
			result.append(origin + Vector2i(x, y))
	return result


## Middle of the footprint in fractional cell coordinates, for drawing and for
## telling a citizen where to walk.
func center() -> Vector2:
	var extent := size()
	return Vector2(origin) + Vector2(extent - Vector2i.ONE) * 0.5


func blocks_movement() -> bool:
	var template := data()
	return template != null and template.blocks_movement


## Where a citizen stands to use this. Either on the object itself (a chair) or
## on a free cell beside it (a stove).
func access_cells(interaction: InteractionData, grid: WorldGrid) -> Array[Vector2i]:
	if interaction != null and interaction.stands_on_furniture:
		return cells()
	var result: Array[Vector2i] = []
	var own := cells()
	for cell in own:
		for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var neighbor: Vector2i = cell + direction
			if own.has(neighbor) or result.has(neighbor):
				continue
			# Reachable means walkable *and* not behind the object's own wall.
			if grid.can_walk_between(cell, neighbor):
				result.append(neighbor)
	return result


func is_free_for(interaction: InteractionData) -> bool:
	if interaction == null:
		return false
	return users.size() < maxi(interaction.capacity, 1)


func save_data() -> Dictionary:
	return {
		"id": id,
		"data_id": String(data_id),
		"x": origin.x,
		"y": origin.y,
		"rot": rotation_steps,
		"floor": floor_index,
	}


static func from_save(entry: Dictionary) -> Furniture:
	var item := Furniture.new()
	item.id = int(entry.get("id", -1))
	item.data_id = StringName(entry.get("data_id", ""))
	item.origin = Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
	item.rotation_steps = int(entry.get("rot", 0))
	item.floor_index = int(entry.get("floor", 0))
	return item
