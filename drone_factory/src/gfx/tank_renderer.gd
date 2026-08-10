class_name TankRenderer
extends MultiMeshInstance2D

## Отрисовка танков одним вызовом.
##
## Танки живут в ангарах, как дроны в портах, поэтому слой почти повторяет
## отрисовку курьеров. Отдельный класс нужен из-за другого источника данных
## и другой раскраски: подбитая техника темнеет, чтобы игрок видел, что
## колонна тает, не открывая ни одной панели.

const CAPACITY_STEP: int = 8

var registry: BuildingRegistry = null
var simulation: Simulation = null

var _capacity: int = 0
var _visible_count: int = 0


func _ready() -> void:
	z_index = 5
	Art.build()
	texture = Art.object_texture
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_colors = true
	multimesh.mesh = DroneRenderer._build_quad(Art.region(ObjectArt.TANK))
	_ensure_capacity(CAPACITY_STEP)


func setup(building_registry: BuildingRegistry, game_simulation: Simulation) -> void:
	registry = building_registry
	simulation = game_simulation


func _process(_delta: float) -> void:
	if registry == null:
		return
	var alpha: float = 0.0 if simulation == null else simulation.tick_alpha()
	var index: int = 0
	for depot: Building in registry.of_kind(BuildingDefs.Kind.TANK_DEPOT):
		for tank: Tank in (depot as TankDepot).tanks:
			if not tank.is_alive():
				continue
			if index >= _capacity:
				_ensure_capacity(_capacity + CAPACITY_STEP)
			multimesh.set_instance_transform_2d(index, instance_transform(tank, alpha))
			multimesh.set_instance_color(index, instance_color(tank))
			index += 1
	_visible_count = index
	multimesh.visible_instance_count = index


func visible_tanks() -> int:
	return _visible_count


static func instance_transform(tank: Tank, alpha: float) -> Transform2D:
	return Transform2D(tank.heading(), tank.render_position(alpha))


static func instance_color(tank: Tank) -> Color:
	var shade: float = 0.4 + 0.6 * tank.health_ratio()
	return Color(shade, shade, shade, 1.0)


func _ensure_capacity(capacity: int) -> void:
	if capacity <= _capacity:
		return
	_capacity = capacity
	multimesh.instance_count = capacity
	multimesh.visible_instance_count = _visible_count
