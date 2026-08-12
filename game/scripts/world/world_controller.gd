class_name WorldController
extends Node2D

## Owns the world model and hands it to the view layers.
##
## This node is the seam between model and view: it creates the WorldGrid,
## registers it with the save system, announces it on the EventBus, and tracks
## which cell the pointer is over. It draws nothing itself — the child layers do
## that, driven by signals.

var grid: WorldGrid

## Cell under the pointer, or `Vector2i(-1, -1)` when the pointer is off-map.
var hovered_cell: Vector2i = Vector2i(-1, -1)

@onready var camera: CameraRig = $CameraRig


func _ready() -> void:
	grid = WorldGrid.new(GameConstants.MAP_SIZE, GameConstants.MAX_FLOORS)
	SaveManager.register("world", self)

	camera.set_bounds_from_map(grid.size)
	camera.focus_cell(Vector2i(grid.size.x / 2, grid.size.y / 2), true)

	# Children are ready before their parent, so every layer is already
	# listening by the time this fires.
	EventBus.world_ready.emit(grid)
	EventBus.notify("World ready: %d x %d cells, %d floor(s)" % [grid.size.x, grid.size.y, grid.floors])

	DebugTools.maybe_build_demo(self)
	DebugTools.maybe_build_showroom(self)
	DebugTools.maybe_benchmark(self)
	PointerTest.maybe_run(self)
	LifeReport.maybe_run(self)
	DebugTools.maybe_screenshot(self)


func _process(_delta: float) -> void:
	_update_hover()


## Pointer position -> cell. Cheap enough to run every frame (two divisions),
## and everything that needs a cell reads it from here instead of repeating the
## conversion.
func _update_hover() -> void:
	var cell := IsoUtils.world_to_cell(get_global_mouse_position())
	if not grid.in_bounds(cell):
		cell = Vector2i(-1, -1)
	if cell != hovered_cell:
		hovered_cell = cell


func has_hover() -> bool:
	return hovered_cell.x >= 0


# --- Persistence ------------------------------------------------------------

func save_data() -> Dictionary:
	return grid.save_data()


func load_data(data: Dictionary) -> void:
	grid.load_data(data)
	camera.set_bounds_from_map(grid.size)
	EventBus.world_ready.emit(grid)
