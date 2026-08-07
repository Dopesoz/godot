class_name DroneRenderer
extends MultiMeshInstance2D

## Отрисовка всех дронов одним вызовом.
##
## MultiMesh даёт один пакет на весь флот независимо от его размера: сто узлов
## Sprite2D — это сто трансформов, сто элементов canvas и заметная просадка на
## слабом Android. Здесь на кадр приходится только запись трансформов в буфер.
##
## Между логическими тиками (10 Гц) положение интерполируется, поэтому полёт
## выглядит плавным при 60 кадрах в секунду.

## Запас мест в буфере: перевыделять MultiMesh на каждого нового дрона дорого.
const CAPACITY_STEP: int = 16

var registry: BuildingRegistry = null
## Источник доли времени между тиками.
var simulation: Simulation = null

var _capacity: int = 0
var _visible_count: int = 0


func _ready() -> void:
	z_index = 6
	Art.build()
	texture = Art.object_texture
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_colors = true
	multimesh.mesh = _build_quad(Art.region(ObjectArt.DRONE))
	_ensure_capacity(CAPACITY_STEP)


func setup(building_registry: BuildingRegistry, game_simulation: Simulation) -> void:
	registry = building_registry
	simulation = game_simulation


func _process(_delta: float) -> void:
	if registry == null:
		return
	var alpha: float = 0.0 if simulation == null else simulation.tick_alpha()
	var index: int = 0

	for port_building: Building in registry.of_kind(BuildingDefs.Kind.DRONE_PORT):
		var port: DronePort = port_building
		for drone: Drone in port.drones:
			if index >= _capacity:
				_ensure_capacity(_capacity + CAPACITY_STEP)
			multimesh.set_instance_transform_2d(index, instance_transform(drone, alpha))
			multimesh.set_instance_color(index, instance_color(drone))
			index += 1

	_visible_count = index
	multimesh.visible_instance_count = index


func visible_drones() -> int:
	return _visible_count


## Положение и поворот дрона на кадре. Вынесено отдельной функцией: буфер
## MultiMesh живёт на стороне рендер-сервера и не читается в headless,
## поэтому проверяется именно расчёт.
static func instance_transform(drone: Drone, alpha: float) -> Transform2D:
	return Transform2D(drone.heading(), drone.render_position(alpha))


## Гружёный дрон подсвечивается цветом груза: видно, что везут,
## не открывая ни одной панели.
static func instance_color(drone: Drone) -> Color:
	return Items.color(drone.cargo_item) if drone.has_cargo() else Color.WHITE


func _ensure_capacity(capacity: int) -> void:
	if capacity <= _capacity:
		return
	_capacity = capacity
	multimesh.instance_count = capacity
	multimesh.visible_instance_count = _visible_count


## Квад с UV, вырезанными под спрайт дрона в общем атласе.
static func _build_quad(region: Rect2i) -> ArrayMesh:
	var half := Vector2(region.size) * 0.5
	var atlas_size := Vector2(Art.object_texture.get_width(), Art.object_texture.get_height())
	var uv_from: Vector2 = Vector2(region.position) / atlas_size
	var uv_to: Vector2 = Vector2(region.end) / atlas_size

	var vertices := PackedVector2Array([
		Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y),
	])
	var uvs := PackedVector2Array([
		uv_from, Vector2(uv_to.x, uv_from.y), uv_to, Vector2(uv_from.x, uv_to.y),
	])
	var indices := PackedInt32Array([0, 1, 2, 0, 2, 3])

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
