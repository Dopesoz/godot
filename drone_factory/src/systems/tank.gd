class_name Tank
extends RefCounted

## Танк: боевая единица, которую игрок отправляет на гнездо.
##
## Устроен как курьер — данные, а не узел сцены, — но подчиняется приказу,
## а не расписанию. Никакого автобоя: танк едет туда, куда его послали, бьёт
## гнездо и возвращается. Это сознательно: игра про фабрику, и армия в ней
## должна быть разовой операцией, а не второй профессией.

enum State { IDLE, DRIVING, ATTACKING, RETURNING }

## Скорость, пикселей в секунду. Медленнее дрона, быстрее носильщика.
const SPEED: float = 56.0
## Урон гнезду в секунду, пока танков хватает.
const DAMAGE_PER_SECOND: int = 14
## На каком расстоянии от цели танк считает, что доехал, пикселей.
const REACH: float = 40.0
const MAX_HEALTH: int = 220

var id: int = 0
var depot_id: int = 0
var state: int = State.IDLE
var health: int = MAX_HEALTH
var target_id: int = 0

var position: Vector2 = Vector2.ZERO
var previous_position: Vector2 = Vector2.ZERO
## Накопленный дробный урон: тик идёт 10 раз в секунду, а урон целочисленный.
## Без накопления четыре единицы в секунду при округлении превращаются в ноль,
## и гнездо перестаёт огрызаться вовсе.
var damage_carry: float = 0.0
var incoming_carry: float = 0.0


## Принимает урон, заданный в единицах в секунду.
func take_damage_over_time(per_second: float, delta: float) -> bool:
	incoming_carry += per_second * delta
	var whole: int = int(incoming_carry)
	if whole <= 0:
		return false
	incoming_carry -= float(whole)
	return take_damage(whole)


func is_alive() -> bool:
	return health > 0


func is_busy() -> bool:
	return state != State.IDLE


func health_ratio() -> float:
	return clampf(float(health) / float(MAX_HEALTH), 0.0, 1.0)


## Возвращает true, если танк уничтожен.
func take_damage(amount: int) -> bool:
	health = maxi(health - maxi(amount, 0), 0)
	return health <= 0


## Шаг к точке. Возвращает true, если доехал.
func drive_to(point: Vector2, delta: float) -> bool:
	previous_position = position
	var offset: Vector2 = point - position
	var distance: float = offset.length()
	if distance <= REACH:
		return true
	position += offset / distance * SPEED * delta
	return false


func heading() -> float:
	var offset: Vector2 = position - previous_position
	return 0.0 if offset.length_squared() < 0.0001 else offset.angle()


func render_position(alpha: float) -> Vector2:
	return previous_position.lerp(position, clampf(alpha, 0.0, 1.0))


func serialize() -> Dictionary:
	return {
		"id": id, "hp": health, "state": state, "target": target_id,
		"x": position.x, "y": position.y,
	}


func deserialize(data: Dictionary) -> void:
	id = int(data.get("id", 0))
	health = int(data.get("hp", MAX_HEALTH))
	state = int(data.get("state", State.IDLE))
	target_id = int(data.get("target", 0))
	position = Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0)))
	previous_position = position
