class_name EventSystem
extends GameSystem

## Редкие события мира. Пока одно: падение метеорита с ценными обломками.
##
## Событие намеренно редкое и приятное, без урона: игра про оптимизацию завода,
## и случайная неприятность, ломающая выстроенную линию, здесь была бы обидной.
## Метеорит — повод оторваться от рутины и слетать за добычей.

## Среднее время между метеоритами, секунды игрового времени.
const MEAN_INTERVAL: float = 420.0
## Раньше этого срока после старта метеориты не падают: новичку хватает забот.
const GRACE_PERIOD: float = 180.0
## На каком расстоянии от базы падает метеорит, клетки.
const MIN_DISTANCE: int = 12
const MAX_DISTANCE: int = 30
## Сколько добычи внутри обломка.
const GOLD_RANGE := Vector2i(20, 60)
const DIAMOND_RANGE := Vector2i(2, 8)

var next_event_time: float = GRACE_PERIOD + MEAN_INTERVAL * 0.5
var meteors_fallen: int = 0


func system_name() -> String:
	return "события"


func reset() -> void:
	next_event_time = GRACE_PERIOD + MEAN_INTERVAL * 0.5
	meteors_fallen = 0


func tick(_delta: float, context: Dictionary) -> void:
	var time: float = float(context.get("tick", 0)) * Constants.TICK_DELTA
	if time < next_event_time:
		return
	_schedule_next(time)
	_drop_meteor(time)


## Интервал случайный, но с гарантированным минимумом: два метеорита подряд
## обесценили бы событие.
func _schedule_next(time: float) -> void:
	var rng: RandomNumberGenerator = Rng.stream(int(time) + meteors_fallen * 977)
	next_event_time = time + MEAN_INTERVAL * rng.randf_range(0.7, 1.6)


func _drop_meteor(time: float) -> void:
	var origin: Vector2i = _find_landing_spot(int(time))
	if origin.x < 0:
		# Свободного места не нашлось — попробуем в следующий раз.
		return
	var wreck: Building = world.buildings.place(BuildingDefs.WRECK, origin)
	if wreck == null:
		return

	var rng: RandomNumberGenerator = Rng.stream(int(time) * 31 + meteors_fallen)
	wreck.output.add(Items.GOLD, rng.randi_range(GOLD_RANGE.x, GOLD_RANGE.y))
	wreck.output.add(Items.DIAMOND, rng.randi_range(DIAMOND_RANGE.x, DIAMOND_RANGE.y))
	meteors_fallen += 1

	Events.building_state_changed.emit(wreck.id)
	Events.notify.emit("Метеорит упал неподалёку — в нём золото и алмазы")


## Ищет свободную площадку в кольце вокруг базы: слишком близко — метеорит
## упал бы в середину фабрики, слишком далеко — игрок его не найдёт.
func _find_landing_spot(seed_value: int) -> Vector2i:
	var home: Vector2i = world.home_cell()
	for attempt: int in 24:
		var angle: float = Rng.value01(seed_value, attempt, 17) * TAU
		var distance: int = Rng.range_int(seed_value, attempt, 29, MIN_DISTANCE, MAX_DISTANCE)
		var origin := home + Vector2i(
			int(cos(angle) * float(distance)), int(sin(angle) * float(distance))
		)
		if world.buildings.can_place(BuildingDefs.WRECK, origin):
			return origin
	return Vector2i(-1, -1)


func serialize() -> Dictionary:
	return {"next": next_event_time, "count": meteors_fallen}


func deserialize(data: Dictionary) -> void:
	next_event_time = float(data.get("next", GRACE_PERIOD))
	meteors_fallen = int(data.get("count", 0))
