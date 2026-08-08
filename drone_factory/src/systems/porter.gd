class_name Porter
extends Drone

## Носильщик — наземный курьер: тот же логистический механизм, что у дрона,
## но пешком.
##
## Зачем он нужен рядом с дронами. Порт дронов стоит микросхем и требует
## постоянного питания, то есть появляется не в первые минуты игры. До этого
## момента игрок таскает всё «руками» — то есть никак, потому что рук в игре
## нет. Носильщики закрывают именно этот участок: дёшево, без электричества,
## медленно и недалеко. Дальше они остаются полезны на мелких развязках,
## куда гонять дрон расточительно.
##
## Наследование от Drone здесь честное, а не ради экономии: состояние, груз,
## интерполяция положения и сериализация у наземного курьера ровно те же.
## Отличий два — скорость и вода под ногами.

## Скорость шага, пикселей в секунду. Примерно вдвое медленнее дрона.
const WALK_SPEED: float = 44.0

## Через сколько пикселей проверяется вода на пути. Полклетки: узкую протоку
## пропустить нельзя, а считать каждый пиксель незачем.
const WATER_PROBE_STEP: float = 16.0


func base_speed() -> float:
	return WALK_SPEED


## Носильщик не умеет плавать. Маршрут прямой, поэтому проверяем прямую:
## обходить озеро он всё равно не станет, а вот пройти сквозь него не должен.
func can_travel(grid: Grid, from: Vector2, to: Vector2) -> bool:
	if grid == null:
		return true
	var delta: Vector2 = to - from
	var distance: float = delta.length()
	if distance <= 0.001:
		return true
	var steps: int = maxi(int(distance / WATER_PROBE_STEP), 1)
	for i: int in steps + 1:
		var point: Vector2 = from + delta * (float(i) / float(steps))
		var cell := Vector2i(
			int(floor(point.x / float(Constants.TILE_SIZE))),
			int(floor(point.y / float(Constants.TILE_SIZE)))
		)
		if not grid.in_bounds(cell):
			continue
		if grid.get_terrain(cell) == TileTypes.Terrain.WATER:
			return false
	return true


## Направление шага. В отличие от дрона спрайт не крутится вокруг оси —
## человечек всегда стоит вертикально, а идёт влево или вправо.
func heading() -> float:
	return 0.0


## Смотрит ли носильщик влево: по этому флагу спрайт отражается.
func faces_left() -> bool:
	return position.x < previous_position.x - 0.01
