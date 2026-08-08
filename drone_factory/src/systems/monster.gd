class_name Monster
extends RefCounted

## Жук: наземный противник.
##
## Устроен как дрон и по тем же причинам — это данные, а не узел сцены. Стая
## в полсотни особей не должна стоить полсотни Node2D с их обходом дерева;
## положение интерполируется между тиками, а рисуется вся стая одним
## MultiMesh.
##
## Поведение нарочно простое: идти к выбранной цели и грызть её. Никакого
## поиска пути и обхода препятствий здесь нет, и это осознанно. Игра про
## оптимизацию фабрики, а не про тактику; стена работает не потому, что жук
## «не может» её обойти, а потому, что он выбирает ближайшее, что мешает,
## и застревает на заборе — ровно то поведение, которого ждут от tower defense.

enum State { WALKING, ATTACKING, DEAD }

## Скорость, пикселей в секунду. Медленнее носильщика: у игрока должно быть
## время увидеть волну и добежать до турели.
const SPEED: float = 32.0
## Урон по зданию за одну атаку.
const DAMAGE: int = 9
## Пауза между укусами, секунды.
const ATTACK_INTERVAL: float = 0.8
## На каком расстоянии жук считает, что дошёл, пикселей.
const REACH: float = 20.0

var id: int = 0
var health: int = 60
var max_health: int = 60
var state: int = State.WALKING

var position: Vector2 = Vector2.ZERO
var previous_position: Vector2 = Vector2.ZERO
var target_id: int = 0
var attack_cooldown: float = 0.0


func is_alive() -> bool:
	return state != State.DEAD and health > 0


## Наносит урон. Возвращает true, если жук убит.
func take_damage(amount: int) -> bool:
	health -= maxi(amount, 0)
	if health <= 0:
		health = 0
		state = State.DEAD
		return true
	return false


## Шаг к точке. Возвращает true, если дошёл.
func advance_to(point: Vector2, delta: float) -> bool:
	previous_position = position
	var offset: Vector2 = point - position
	var distance: float = offset.length()
	if distance <= REACH:
		return true
	position += offset / distance * SPEED * delta
	return false


## Направление движения — для поворота спрайта.
func heading() -> float:
	var offset: Vector2 = position - previous_position
	return 0.0 if offset.length_squared() < 0.0001 else offset.angle()


## Положение на кадре: между тиками движение интерполируется.
func render_position(alpha: float) -> Vector2:
	return previous_position.lerp(position, clampf(alpha, 0.0, 1.0))


func health_ratio() -> float:
	return 0.0 if max_health <= 0 else clampf(float(health) / float(max_health), 0.0, 1.0)


func serialize() -> Dictionary:
	return {
		"id": id, "hp": health, "max": max_health, "state": state,
		"x": position.x, "y": position.y, "target": target_id,
	}


func deserialize(data: Dictionary) -> void:
	id = int(data.get("id", 0))
	health = int(data.get("hp", 60))
	max_health = int(data.get("max", maxi(health, 1)))
	state = int(data.get("state", State.WALKING))
	position = Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0)))
	previous_position = position
	target_id = int(data.get("target", 0))
