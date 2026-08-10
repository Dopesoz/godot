class_name MonsterRenderer
extends MultiMeshInstance2D

## Отрисовка стаи жуков одним вызовом — тем же способом, что и курьеров.
##
## Отдельный класс, а не настройка DroneRenderer: жуки живут не в зданиях,
## а в боевой системе, и красятся по остатку здоровья, а не по грузу.

const CAPACITY_STEP: int = 32
## Сколько шагов лапами в секунду. Медленнее выглядит вяло, быстрее — дрожью.
const STEP_RATE: float = 6.0

var simulation: Simulation = null
var combat: CombatSystem = null

## Второй кадр анимации. MultiMesh рисует все экземпляры одним мешем, поэтому
## два положения лап — это два слоя, между которыми стая делится по фазе шага.
## Цена — один лишний вызов отрисовки на всю стаю, и это дёшево.
var _alternate: MultiMeshInstance2D = null

var _capacity: int = 0
var _visible_count: int = 0
var _time: float = 0.0


func _ready() -> void:
	z_index = 5
	Art.build()
	texture = Art.object_texture
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_colors = true
	multimesh.mesh = DroneRenderer._build_quad(Art.region(ObjectArt.MONSTER))

	_alternate = MultiMeshInstance2D.new()
	_alternate.name = "AlternateFrame"
	_alternate.texture = Art.object_texture
	_alternate.multimesh = MultiMesh.new()
	_alternate.multimesh.transform_format = MultiMesh.TRANSFORM_2D
	_alternate.multimesh.use_colors = true
	_alternate.multimesh.mesh = DroneRenderer._build_quad(Art.region(ObjectArt.MONSTER_ALT))
	add_child(_alternate)

	_ensure_capacity(CAPACITY_STEP)


func setup(game_simulation: Simulation) -> void:
	simulation = game_simulation
	combat = null if simulation == null else simulation.get_system(CombatSystem) as CombatSystem


func _process(delta: float) -> void:
	if combat == null:
		return
	_time += delta
	var alpha: float = 0.0 if simulation == null else simulation.tick_alpha()
	var main_index: int = 0
	var alt_index: int = 0

	for monster: Monster in combat.monsters:
		if not monster.is_alive():
			continue
		if maxi(main_index, alt_index) >= _capacity:
			_ensure_capacity(_capacity + CAPACITY_STEP)
		var transform: Transform2D = instance_transform(monster, alpha)
		var colour: Color = instance_color(monster)
		# Фаза сдвинута по номеру жука: стая не должна маршировать в ногу.
		if is_stepping(_time, monster):
			_alternate.multimesh.set_instance_transform_2d(alt_index, transform)
			_alternate.multimesh.set_instance_color(alt_index, colour)
			alt_index += 1
		else:
			multimesh.set_instance_transform_2d(main_index, transform)
			multimesh.set_instance_color(main_index, colour)
			main_index += 1

	_visible_count = main_index + alt_index
	multimesh.visible_instance_count = main_index
	_alternate.multimesh.visible_instance_count = alt_index


## На каком кадре шага находится жук прямо сейчас.
static func is_stepping(time: float, monster: Monster) -> bool:
	# Стоящий жук лапами не перебирает: анимация должна означать движение.
	if monster.state == Monster.State.ATTACKING:
		return false
	return int(time * STEP_RATE + float(monster.id)) % 2 == 1


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
	multimesh.visible_instance_count = 0
	_alternate.multimesh.instance_count = capacity
	_alternate.multimesh.visible_instance_count = 0
