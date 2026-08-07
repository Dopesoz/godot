class_name TouchInput
extends Node

## Распознавание жестов для управления одним пальцем.
##
## Набор жестов подобран так, чтобы игра полностью управлялась большим пальцем
## одной руки:
##   тап                   — выбрать клетку / здание, поставить постройку;
##   перетаскивание        — двигать карту, с броском по инерции;
##   долгое нажатие        — контекстное действие (меню клетки);
##   двойной тап           — приблизить на шаг;
##   двойной тап + протяжка — зум без второго пальца (главный жест «одной рукой»);
##   щипок двумя пальцами  — привычный зум, если рук всё-таки две.
##
## Узел только распознаёт жесты: камерой он двигает сам (это её прямое
## управление), а игровые события отдаёт сигналами наверх.

signal tapped(screen_position: Vector2)
signal long_pressed(screen_position: Vector2)
signal drag_started()
signal drag_ended()

## Двойной тап засчитывается, если второе касание пришло не позже этого времени.
const DOUBLE_TAP_TIME: float = 0.32
## ...и не дальше этого расстояния от первого.
const DOUBLE_TAP_DISTANCE: float = 48.0
## Сколько зума даёт один шаг двойного тапа.
const DOUBLE_TAP_ZOOM_STEP: float = 1.6
## Пикселей протяжки на удвоение масштаба в режиме «двойной тап + протяжка».
const DRAG_ZOOM_PIXELS: float = 260.0
## Сглаживание скорости для броска: доля нового замера в накопленной скорости.
const VELOCITY_SMOOTHING: float = 0.35
## Скорость колеса мыши в зум (только для отладки на десктопе).
const WHEEL_ZOOM_STEP: float = 1.12

enum Gesture { NONE, TAP_PENDING, PANNING, DRAG_ZOOM, PINCH }

var camera: GameCamera = null
## Включает и выключает распознавание (например, на паузе).
var enabled: bool = true

var _gesture: int = Gesture.NONE
## Активные касания: индекс пальца -> позиция.
var _touches: Dictionary[int, Vector2] = {}
var _primary_index: int = -1
var _press_position: Vector2 = Vector2.ZERO
var _last_position: Vector2 = Vector2.ZERO
var _press_time: float = 0.0
var _velocity: Vector2 = Vector2.ZERO
var _long_press_fired: bool = false
var _last_tap_time: float = -1.0
var _last_tap_position: Vector2 = Vector2.ZERO
var _pinch_distance: float = 0.0
var _drag_zoom_anchor: Vector2 = Vector2.ZERO
var _time: float = 0.0


func _unhandled_input(event: InputEvent) -> void:
	handle_event(event)


func _process(delta: float) -> void:
	_time += delta
	_check_long_press()


## Точка входа для событий: вынесена отдельно, чтобы тесты подавали жесты
## напрямую, без вьюпорта.
func handle_event(event: InputEvent) -> void:
	if not enabled or camera == null:
		return
	if event is InputEventScreenTouch:
		_handle_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_drag(event as InputEventScreenDrag)
	elif event is InputEventMouseButton:
		_handle_wheel(event as InputEventMouseButton)


func is_gesture_active() -> bool:
	return _gesture != Gesture.NONE


## Сбрасывает состояние: нужно при открытии модальных окон и паузе.
func cancel() -> void:
	if _gesture == Gesture.PANNING:
		drag_ended.emit()
	_touches.clear()
	_gesture = Gesture.NONE
	_primary_index = -1
	_velocity = Vector2.ZERO


## --- Касания ---------------------------------------------------------------

func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touches[event.index] = event.position
		if _touches.size() == 1:
			_begin_single_touch(event)
		elif _touches.size() == 2:
			_begin_pinch()
		return

	_touches.erase(event.index)
	if event.index == _primary_index:
		_end_single_touch(event)
	if _touches.size() < 2 and _gesture == Gesture.PINCH:
		# Один палец остался — продолжаем как перетаскивание, без рывка.
		_gesture = Gesture.NONE
		if not _touches.is_empty():
			_primary_index = _touches.keys()[0]
			_press_position = _touches[_primary_index]
			_last_position = _press_position
			_press_time = _time
			_long_press_fired = true


func _begin_single_touch(event: InputEventScreenTouch) -> void:
	_primary_index = event.index
	_press_position = event.position
	_last_position = event.position
	_press_time = _time
	_long_press_fired = false
	_velocity = Vector2.ZERO
	camera.stop_inertia()

	var is_double: bool = (
		_last_tap_time >= 0.0
		and _time - _last_tap_time <= DOUBLE_TAP_TIME
		and event.position.distance_to(_last_tap_position) <= DOUBLE_TAP_DISTANCE
	)
	if is_double:
		# Второе касание двойного тапа: если игрок потянет — это зум одним пальцем,
		# если отпустит — шаг приближения.
		_gesture = Gesture.DRAG_ZOOM
		_drag_zoom_anchor = event.position
		_long_press_fired = true
		_last_tap_time = -1.0
	else:
		_gesture = Gesture.TAP_PENDING


func _end_single_touch(event: InputEventScreenTouch) -> void:
	match _gesture:
		Gesture.TAP_PENDING:
			if not _long_press_fired:
				tapped.emit(event.position)
				_last_tap_time = _time
				_last_tap_position = event.position
		Gesture.PANNING:
			camera.fling(_velocity)
			drag_ended.emit()
		Gesture.DRAG_ZOOM:
			# Потянуть не успели — засчитываем как шаг приближения двойным тапом.
			if event.position.distance_to(_drag_zoom_anchor) < Constants.TOUCH_DRAG_THRESHOLD:
				camera.zoom_at(DOUBLE_TAP_ZOOM_STEP, event.position)
		_:
			pass
	_gesture = Gesture.NONE
	_primary_index = -1


func _handle_drag(event: InputEventScreenDrag) -> void:
	_touches[event.index] = event.position

	if _gesture == Gesture.PINCH:
		_update_pinch()
		return
	if event.index != _primary_index:
		return

	if _gesture == Gesture.DRAG_ZOOM:
		# Вверх — приближение, вниз — отдаление; якорь остаётся на месте.
		var factor: float = pow(2.0, -event.relative.y / DRAG_ZOOM_PIXELS)
		camera.zoom_at(factor, _drag_zoom_anchor)
		return

	if _gesture == Gesture.TAP_PENDING:
		if event.position.distance_to(_press_position) < Constants.TOUCH_DRAG_THRESHOLD:
			return
		_gesture = Gesture.PANNING
		drag_started.emit()

	if _gesture != Gesture.PANNING:
		return

	camera.pan_by_screen(event.relative)
	_last_position = event.position
	# Скорость сглаживаем: сырой последний кадр даёт непредсказуемый бросок.
	if event.velocity != Vector2.ZERO:
		_velocity = _velocity.lerp(event.velocity, VELOCITY_SMOOTHING)


func _begin_pinch() -> void:
	_gesture = Gesture.PINCH
	_pinch_distance = _current_pinch_distance()
	_long_press_fired = true


func _update_pinch() -> void:
	var distance: float = _current_pinch_distance()
	if _pinch_distance <= 1.0 or distance <= 1.0:
		_pinch_distance = distance
		return
	camera.zoom_at(distance / _pinch_distance, _pinch_center())
	_pinch_distance = distance


func _current_pinch_distance() -> float:
	var points: Array[Vector2] = _touch_positions()
	if points.size() < 2:
		return 0.0
	return points[0].distance_to(points[1])


func _pinch_center() -> Vector2:
	var points: Array[Vector2] = _touch_positions()
	if points.size() < 2:
		return camera.view_size() * 0.5
	return (points[0] + points[1]) * 0.5


func _touch_positions() -> Array[Vector2]:
	var points: Array[Vector2] = []
	for index: int in _touches:
		points.append(_touches[index])
	return points


func _check_long_press() -> void:
	if _gesture != Gesture.TAP_PENDING or _long_press_fired:
		return
	if _time - _press_time < Constants.TOUCH_LONG_PRESS_TIME:
		return
	if _last_position.distance_to(_press_position) >= Constants.TOUCH_DRAG_THRESHOLD:
		return
	_long_press_fired = true
	long_pressed.emit(_press_position)


func _handle_wheel(event: InputEventMouseButton) -> void:
	if not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		camera.zoom_at(WHEEL_ZOOM_STEP, event.position)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		camera.zoom_at(1.0 / WHEEL_ZOOM_STEP, event.position)
