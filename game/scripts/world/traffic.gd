class_name Traffic
extends Node

## Cars, driving on the roads.
##
## They are scenery, and deliberately so: they never carry anyone, never block
## anyone, and nobody waits for them. A city that moves reads as alive from far
## away, which is exactly the distance at which the residents are too small to
## watch — so this fills the one gap the simulation leaves, at the price of a
## dozen positions updated per frame and nothing else.
##
## Being scenery is also why they are not SimAgents and are not saved: there is
## no state here worth restoring. Reopening a town respawns the traffic, and
## nobody can tell.

## One car per this many road cells, so a village gets two and a city gets a
## dozen without anyone tuning a number.
const CELLS_PER_CAR := 26
const MAX_CARS := 16
## Cells per game minute. A resident walks at 1.6, and a car that only just
## outpaced a pedestrian would look broken.
const SPEED := 7.0

class Car:
	var position: Vector2
	var direction: Vector2i
	var target: Vector2i
	var color_index: int

	## True when the car is heading towards the bottom of the screen, which is
	## the half of the sprites that show a windscreen rather than a boot.
	func coming() -> bool:
		return direction.x + direction.y > 0

	func along_x() -> bool:
		return direction.x != 0

var cars: Array[Car] = []

var _grid: WorldGrid
var _roads: Array[Vector2i] = []
var _road_set: Dictionary = {}
var _rescan_queued: bool = false


func _ready() -> void:
	EventBus.world_ready.connect(_on_world_ready)
	EventBus.cell_changed.connect(_on_cell_changed)


func _on_world_ready(world: WorldGrid) -> void:
	_grid = world
	_rescan.call_deferred()


func _on_cell_changed(_cell: Vector2i, _floor_index: int) -> void:
	# A road can be painted or dug up at any time; the fleet follows on the next
	# idle frame rather than on every single tile of a drag. One scan per frame
	# at most — building a town changes thousands of cells, and without the flag
	# each of them would queue its own sweep of the whole map.
	if _rescan_queued:
		return
	_rescan_queued = true
	_rescan.call_deferred()


func _rescan() -> void:
	_rescan_queued = false
	if _grid == null:
		return
	_roads.clear()
	_road_set.clear()
	for y in _grid.size.y:
		for x in _grid.size.x:
			var cell := Vector2i(x, y)
			if _is_road(cell):
				_roads.append(cell)
				_road_set[cell] = true
	var wanted := mini(_roads.size() / CELLS_PER_CAR, MAX_CARS)
	while cars.size() > wanted:
		cars.pop_back()
	while cars.size() < wanted:
		var car := _spawn()
		if car == null:
			break
		cars.append(car)


func _is_road(cell: Vector2i) -> bool:
	var data := _grid.get_cell(cell)
	if data == null or data.floor_id == &"":
		return false
	var material := Database.get_floor(data.floor_id)
	return material != null and material.is_road


func _spawn() -> Car:
	for attempt in 12:
		var cell: Vector2i = _roads[randi() % _roads.size()]
		var exits := _exits(cell, Vector2i.ZERO)
		if exits.is_empty():
			continue
		var car := Car.new()
		car.position = Vector2(cell)
		car.direction = exits[randi() % exits.size()]
		car.target = cell + car.direction
		car.color_index = randi()
		return car
	return null


## Where a car standing on `cell` could go next, never straight back the way it
## came unless there is nowhere else — a dead end is a legitimate reason to turn
## around.
func _exits(cell: Vector2i, from: Vector2i) -> Array[Vector2i]:
	var options: Array[Vector2i] = []
	var back := -from
	for direction in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
		if _road_set.has(cell + direction) and direction != back:
			options.append(direction)
	if options.is_empty() and _road_set.has(cell + back):
		options.append(back)
	return options


func _process(delta: float) -> void:
	if cars.is_empty():
		return
	var minutes := delta * GameConstants.GAME_MINUTES_PER_REAL_SECOND * GameClock.get_speed()
	if minutes <= 0.0:
		return
	var budget := SPEED * minutes
	for car in cars:
		_advance(car, budget)


func _advance(car: Car, budget: float) -> void:
	var remaining := budget
	# A loop rather than a single step, because at sixteen times speed a car
	# covers more than one cell per frame and would otherwise crawl.
	for step in 4:
		var to := Vector2(car.target)
		var offset := to - car.position
		var distance := offset.length()
		if distance > remaining:
			car.position += offset / maxf(distance, 0.0001) * remaining
			return
		car.position = to
		remaining -= distance
		var exits := _exits(car.target, car.direction)
		if exits.is_empty():
			return
		# Straight on if it can, so cars do not jitter at every junction.
		var choice: Vector2i = car.direction if exits.has(car.direction) and randf() < 0.75 \
				else exits[randi() % exits.size()]
		car.direction = choice
		car.target = car.target + choice
