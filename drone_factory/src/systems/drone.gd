class_name Drone
extends RefCounted

## Дрон — единственный вид логистики в игре: конвейеров нет.
##
## Дрон представлен данными, а не узлом сцены: сотня Node2D с _process
## съедает больше, чем вся остальная симуляция. Позиции пересчитываются в
## логическом тике (10 Гц), а рисуются с интерполяцией между тиками — глаз
## видит плавный полёт, процессор считает вдесятеро реже.

enum State { IDLE, TO_SOURCE, TO_TARGET, RETURNING }

## Скорость полёта, пикселей в секунду.
const SPEED: float = 90.0
## Расстояние, на котором цель считается достигнутой.
const ARRIVE_DISTANCE: float = 3.0

var id: int = 0
var port_id: int = 0
var state: int = State.IDLE

var position: Vector2 = Vector2.ZERO
## Позиция на предыдущем тике: по ней рисование интерполирует полёт.
var previous_position: Vector2 = Vector2.ZERO
var target_position: Vector2 = Vector2.ZERO

var source_id: int = 0
var target_id: int = 0
var cargo_item: StringName = &""
var cargo_count: int = 0
## Множитель скорости от исследований, ставится логистикой.
var speed_multiplier: float = 1.0


func is_busy() -> bool:
	return state != State.IDLE


func has_cargo() -> bool:
	return cargo_count > 0


func clear_task() -> void:
	state = State.IDLE
	source_id = 0
	target_id = 0
	cargo_item = &""
	cargo_count = 0


## Базовая скорость. Метод, а не только константа: наземный носильщик
## медленнее дрона, а константы в GDScript не переопределяются наследником.
func base_speed() -> float:
	return SPEED


## Может ли курьер добраться от одной точки к другой. Дрону всё равно,
## носильщик обходит воду.
func can_travel(_grid: Grid, _from: Vector2, _to: Vector2) -> bool:
	return true


func fly_to(destination: Vector2) -> void:
	target_position = destination


## Шаг полёта. Возвращает true, если дрон достиг цели на этом тике.
func advance(delta: float) -> bool:
	previous_position = position
	var to_target: Vector2 = target_position - position
	var distance: float = to_target.length()
	if distance <= ARRIVE_DISTANCE:
		position = target_position
		return true
	var step: float = base_speed() * speed_multiplier * delta
	if step >= distance:
		position = target_position
		return true
	position += to_target / distance * step
	return false


## Направление полёта для поворота спрайта.
func heading() -> float:
	var delta: Vector2 = position - previous_position
	if delta.length_squared() < 0.0001:
		return 0.0
	return delta.angle()


## Положение для отрисовки: alpha — доля пройденного времени между тиками.
func render_position(alpha: float) -> Vector2:
	return previous_position.lerp(position, clampf(alpha, 0.0, 1.0))


func serialize() -> Dictionary:
	return {
		"id": id,
		"s": state,
		"x": position.x,
		"y": position.y,
		"src": source_id,
		"dst": target_id,
		"item": String(cargo_item),
		"n": cargo_count,
	}


func deserialize(data: Dictionary) -> void:
	id = int(data.get("id", 0))
	state = int(data.get("s", State.IDLE))
	position = Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0)))
	previous_position = position
	target_position = position
	source_id = int(data.get("src", 0))
	target_id = int(data.get("dst", 0))
	cargo_item = StringName(data.get("item", ""))
	cargo_count = int(data.get("n", 0))
	# Задание могло ссылаться на снесённое здание: логистика переназначит его
	# на первом же тике, а груз останется при дроне.
	if cargo_count <= 0:
		cargo_item = &""
