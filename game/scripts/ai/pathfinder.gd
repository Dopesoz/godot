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

	var open: Array[Vector2i] = [from]
	# cell -> cost so far, and cell -> where we came from.
	var cost := {from: 0}
	var came_from := {}
	var expanded := 0

	while not open.is_empty():
		var current := _pop_best(open, cost, to)
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
			open.append(neighbor)
	return []


## Linear scan for the lowest f-score. With a 40x40 map the open set stays small
## enough that a real priority queue would cost more in allocation than it saves;
## this is the swap to make when the city grows.
static func _pop_best(open: Array[Vector2i], cost: Dictionary, goal: Vector2i) -> Vector2i:
	var best_index := 0
	var best_score := 1 << 30
	for i in open.size():
		var cell := open[i]
		var score: int = int(cost[cell]) + IsoUtils.cell_distance(cell, goal)
		if score < best_score:
			best_score = score
			best_index = i
	var best := open[best_index]
	open.remove_at(best_index)
	return best


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
