class_name MonsterRenderer
extends MultiMeshInstance2D

## Отрисовка стаи жуков одним вызовом — тем же способом, что и курьеров.
##
## Отдельный класс, а не настройка DroneRenderer: жуки живут не в зданиях,
## а в боевой системе, и красятся по остатку здоровья, а не по грузу.

const CAPACITY_STEP: int = 32

var simulation: Simulation = null
var combat: CombatSystem = null

var _capacity: int = 0
var _visible_count: int = 0


func _ready() -> void:
	z_index = 5
	Art.build()
	texture = Art.object_texture
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_colors = true
	multimesh.mesh = DroneRenderer._build_quad(Art.region(ObjectArt.MONSTER))
	_ensure_capacity(CAPACITY_STEP)


func setup(game_simulation: Simulation) -> void:
	simulation = game_simulation
	combat = null if simulation == null else simulation.get_system(CombatSystem) as CombatSystem


func _process(_delta: float) -> void:
	if combat == null:
		return
	var alpha: float = 0.0 if simulation == null else simulation.tick_alpha()
	var index: int = 0
	for monster: Monster in combat.monsters:
		if not monster.is_alive():
			continue
		if index >= _capacity:
			_ensure_capacity(_capacity + CAPACITY_STEP)
		multimesh.set_instance_transform_2d(index, instance_transform(monster, alpha))
		multimesh.set_instance_color(index, instance_color(monster))
		index += 1
	_visible_count = index
	multimesh.visible_instance_count = index


func visible_monsters() -> int:
	return _visible_count


static func instance_transform(monster: Monster, alpha: float) -> Transform2D:
	return Transform2D(monster.heading(), monster.render_position(alpha))


## Раненый жук темнеет: видно, что турель работает, без полосок здоровья
## над каждой особью.
static func instance_color(monster: Monster) -> Color:
	var health: float = 0.35 + 0.65 * monster.health_ratio()
	return Color(health, health * 0.9, health * 0.9, 1.0)


func _ensure_capacity(capacity: int) -> void:
	if capacity <= _capacity:
		return
	_capacity = capacity
	multimesh.instance_count = capacity
	multimesh.visible_instance_count = _visible_count
