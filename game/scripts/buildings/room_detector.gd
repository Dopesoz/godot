class_name RoomDetector
extends RefCounted

## Turns walls into rooms (design doc §8).
##
## The rule is one flood fill: starting from a cell, spread to orthogonal
## neighbours whenever the edge between them is NOT solid. Doors and windows
## count as solid here — a room with a door is still a room — which is exactly
## why WorldGrid separates `is_edge_passable` (for walking) from `is_edge_solid`
## (for enclosure).
##
## A region that reaches the map border is the outdoors, not a room. Since walls
## can only be drawn between cells, escaping to the border is the same question
## as "is this space open to the outside".
##
## Cost: one pass over the map, O(cells). At 40x40 that is nothing; it runs once
## per finished build action, not per frame. When the city grows past a few
## thousand cells, this becomes a per-building fill seeded from the changed edge
## — the signature stays the same.


static func detect(grid: WorldGrid, floor_index: int = 0) -> Array[Room]:
	var rooms: Array[Room] = []
	var visited := {}
	var next_id := 1

	for y in grid.size.y:
		for x in grid.size.x:
			var start := Vector2i(x, y)
			if visited.has(start):
				continue
			var region := _flood(grid, start, floor_index, visited)
			if region["open"]:
				continue
			var room := _build_room(grid, region["cells"], floor_index)
			room.id = next_id
			next_id += 1
			rooms.append(room)
	return rooms


## Breadth-first fill from `start`. Returns the cells reached and whether the
## region leaked to the outside.
static func _flood(grid: WorldGrid, start: Vector2i, floor_index: int, visited: Dictionary) -> Dictionary:
	var cells: Array[Vector2i] = []
	var queue: Array[Vector2i] = [start]
	var open := false
	visited[start] = true

	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		cells.append(cell)
		for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var neighbor: Vector2i = cell + direction
			if grid.is_edge_solid(WorldGrid.edge_key(cell, direction), floor_index):
				continue
			if not grid.in_bounds(neighbor):
				# Nothing stops us leaving the map here, so this is outdoors.
				open = true
				continue
			if visited.has(neighbor):
				continue
			visited[neighbor] = true
			queue.append(neighbor)

	return {"cells": cells, "open": open}


static func _build_room(grid: WorldGrid, cells: Array[Vector2i], floor_index: int) -> Room:
	var room := Room.new()
	room.cells = cells
	room.floor_index = floor_index
	var seen := {}
	for cell in cells:
		for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var edge := WorldGrid.edge_key(cell, direction)
			if seen.has(edge):
				continue
			seen[edge] = true
			match grid.get_edge(edge, floor_index):
				GameEnums.EdgeType.DOOR:
					room.door_edges.append(edge)
				GameEnums.EdgeType.WINDOW:
					room.window_edges.append(edge)
	return room
