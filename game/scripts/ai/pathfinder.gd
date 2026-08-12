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
		occupied_goal: bool = false, node_budget: int = MAX_NODES) -> Array[Vector2i]:
	if from == to:
		return []
	if grid == null or not grid.in_bounds(to):
		return []
	if not occupied_goal and not grid.is_walkable(to, floor_index):
		return []
	var targets: Array[Vector2i] = [to]
	return _search(grid, from, {to: true}, targets, floor_index, occupied_goal, node_budget)


## Shortest path to whichever of `targets` is cheapest to reach. Used to walk to
## "any free cell beside the stove", or to any cell of the bed itself.
##
## One search, not one per target. It used to run a full A* for every access
## cell and keep the best, which is up to eight searches for one decision — and
## when the object was unreachable, eight *exhaustive* searches. With a hundred
## residents that was four million node expansions in four seconds of play. The
## goal test simply accepts any of the targets, and the heuristic is the
## distance to the nearest of them, which is still admissible.
##
## An empty result means either "already standing on a target" or "no route" —
## callers check whether they are on one first.
static func find_path_to_any(grid: WorldGrid, from: Vector2i, targets: Array[Vector2i],
		floor_index: int = 0, occupied_goal: bool = false,
		node_budget: int = MAX_NODES) -> Array[Vector2i]:
	if grid == null or targets.is_empty():
		return []
	var goals := {}
	for target in targets:
		if target == from:
			return []
		if grid.in_bounds(target) and (occupied_goal or grid.is_walkable(target, floor_index)):
			goals[target] = true
	if goals.is_empty():
		return []
	return _search(grid, from, goals, targets, floor_index, occupied_goal, node_budget)


## The one A*. `goals` is the set to stop at, `targets` the same cells as a list
## for the heuristic.
static func _search(grid: WorldGrid, from: Vector2i, goals: Dictionary,
		targets: Array[Vector2i], floor_index: int, occupied_goal: bool,
		node_budget: int) -> Array[Vector2i]:
	var heap_cells: Array[Vector2i] = []
	var heap_scores := PackedInt32Array()
	var cost := {from: 0}
	var came_from := {}
	var closed := {}
	var expanded := 0
	_heap_push(heap_cells, heap_scores, from, _heuristic(from, targets))

	while not heap_cells.is_empty():
		var current := _heap_pop(heap_cells, heap_scores)
		if closed.has(current):
			continue
		closed[current] = true
		if goals.has(current):
			return _rebuild(came_from, current)
		expanded += 1
		if expanded > node_budget:
			break
		for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var neighbor: Vector2i = current + direction
			if not grid.in_bounds(neighbor):
				continue
			if not grid.is_edge_passable(WorldGrid.edge_between(current, neighbor), floor_index):
				continue
			# The goal may be an object the citizen is about to sit on; anything
			# else on the way has to be genuinely walkable.
			if not (occupied_goal and goals.has(neighbor)) and not grid.is_walkable(neighbor, floor_index):
				continue
			var next_cost: int = int(cost[current]) + 1
			if cost.has(neighbor) and int(cost[neighbor]) <= next_cost:
				continue
			cost[neighbor] = next_cost
			came_from[neighbor] = current
			_heap_push(heap_cells, heap_scores, neighbor, next_cost + _heuristic(neighbor, targets))
	return []


## Distance to the nearest target. Never over-estimates, so A* still returns the
## shortest route.
static func _heuristic(cell: Vector2i, targets: Array[Vector2i]) -> int:
	var best := 1 << 30
	for target in targets:
		best = mini(best, IsoUtils.cell_distance(cell, target))
	return best


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
