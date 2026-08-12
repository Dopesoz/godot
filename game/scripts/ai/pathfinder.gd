class_name Pathfinder
extends RefCounted

## A* over grid cells (design doc §13).
##
## It asks the world exactly one question — `WorldGrid.can_walk_between` — so
## walls, doors and furniture are all handled by the rule that already exists.
## There is no navigation mesh to keep in sync, and knocking a wall down changes
## pathing immediately with no rebuild step.
##
## Movement is 4-way on purpose: a diagonal step between two cells that share
## only a corner would let a citizen cut through a wall junction.

## Safety valve. A citizen asking for an impossible path must not stall the
## frame; 4000 nodes covers any route inside a 40x40 map many times over.
const MAX_NODES := 4000


## Cells from `from` to `to`, excluding the starting cell. Empty when there is
## no route, so callers can simply check `is_empty()`.
##
## `occupied_goal` exists for furniture you sit or lie on: a bed marks its own
## cells as occupied, so the destination is by definition not walkable. Setting
## it lets the final step land on the object while every other rule — walls,
## doors, other furniture — still applies.
static func find_path(grid: WorldGrid, from: Vector2i, to: Vector2i, floor_index: int = 0,
		occupied_goal: bool = false) -> Array[Vector2i]:
	if from == to:
		return []
	if not grid.in_bounds(to):
		return []
	if not occupied_goal and not grid.is_walkable(to, floor_index):
		return []

	# A binary heap, in two parallel arrays: the cell and the f-score it was
	# pushed with. Stale entries are left in place and skipped when popped —
	# cheaper than finding and updating them.
	var heap_cells: Array[Vector2i] = []
	var heap_scores: PackedInt32Array = PackedInt32Array()
	# cell -> cost so far, and cell -> where we came from.
	var cost := {from: 0}
	var came_from := {}
	var closed := {}
	var expanded := 0
	_heap_push(heap_cells, heap_scores, from, IsoUtils.cell_distance(from, to))

	while not heap_cells.is_empty():
		var current := _heap_pop(heap_cells, heap_scores)
		if closed.has(current):
			continue
		closed[current] = true
		if current == to:
			return _rebuild(came_from, to)
		expanded += 1
		if expanded > MAX_NODES:
			break
		for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var neighbor: Vector2i = current + direction
			if not grid.in_bounds(neighbor):
				continue
			if not grid.is_edge_passable(WorldGrid.edge_between(current, neighbor), floor_index):
				continue
			# The goal may be an object the citizen is about to sit on; anything
			# else on the way has to be genuinely walkable.
			if not (occupied_goal and neighbor == to) and not grid.is_walkable(neighbor, floor_index):
				continue
			var next_cost: int = int(cost[current]) + 1
			if cost.has(neighbor) and int(cost[neighbor]) <= next_cost:
				continue
			cost[neighbor] = next_cost
			came_from[neighbor] = current
			_heap_push(heap_cells, heap_scores, neighbor,
					next_cost + IsoUtils.cell_distance(neighbor, to))
	return []


## The open set used to be scanned linearly for the lowest f-score, with a note
## saying that was fine on a 40x40 map and would need swapping when the city
## grew. The city grew: on 64x64 a search that fails explores thousands of
## nodes, each scan walks the whole open set, and one decision could cost a
## third of a second. This is that swap — an ordinary binary heap, which turns
## the cost per node from "length of the open set" into "its logarithm".
static func _heap_push(cells: Array[Vector2i], scores: PackedInt32Array,
		cell: Vector2i, score: int) -> void:
	cells.append(cell)
	scores.append(score)
	var index := cells.size() - 1
	while index > 0:
		var parent := (index - 1) / 2
		if scores[parent] <= scores[index]:
			break
		_heap_swap(cells, scores, parent, index)
		index = parent


static func _heap_pop(cells: Array[Vector2i], scores: PackedInt32Array) -> Vector2i:
	var top := cells[0]
	var last := cells.size() - 1
	_heap_swap(cells, scores, 0, last)
	cells.remove_at(last)
	scores.remove_at(last)
	var index := 0
	while true:
		var left := index * 2 + 1
		var right := left + 1
		var smallest := index
		if left < cells.size() and scores[left] < scores[smallest]:
			smallest = left
		if right < cells.size() and scores[right] < scores[smallest]:
			smallest = right
		if smallest == index:
			break
		_heap_swap(cells, scores, index, smallest)
		index = smallest
	return top


static func _heap_swap(cells: Array[Vector2i], scores: PackedInt32Array, a: int, b: int) -> void:
	var cell := cells[a]
	cells[a] = cells[b]
	cells[b] = cell
	var score := scores[a]
	scores[a] = scores[b]
	scores[b] = score


static func _rebuild(came_from: Dictionary, to: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [to]
	var cursor := to
	while came_from.has(cursor):
		cursor = came_from[cursor]
		path.append(cursor)
	path.reverse()
	path.remove_at(0)  # the cell we are already standing on
	return path


## Shortest path to whichever of `targets` is cheapest to reach. Used to walk to
## "any free cell beside the stove", or to any cell of the bed itself.
##
## An empty result means either "already standing on a target" or "no route" —
## callers check whether they are on one first.
static func find_path_to_any(grid: WorldGrid, from: Vector2i, targets: Array[Vector2i], floor_index: int = 0,
		occupied_goal: bool = false) -> Array[Vector2i]:
	var best: Array[Vector2i] = []
	for target in targets:
		if target == from:
			return []
		var path := find_path(grid, from, target, floor_index, occupied_goal)
		if path.is_empty():
			continue
		if best.is_empty() or path.size() < best.size():
			best = path
	return best
