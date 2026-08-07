class_name Rng
extends RefCounted

## Детерминированный шум по координатам без хранения состояния.
##
## Нужен там, где результат обязан воспроизводиться из одного лишь сида:
## разброс декора, вариации тайлов, дрожание маршрутов дронов. Такие данные
## не попадают в сохранение — они пересчитываются на лету.

const _PRIME_X: int = 0x27D4EB2D
const _PRIME_Y: int = 0x165667B1
const _PRIME_S: int = 0x9E3779B1
const _MASK: int = 0x7FFFFFFF


## 31-битный хеш от пары координат и сида.
static func hash2i(x: int, y: int, seed_value: int) -> int:
	var h: int = (x * _PRIME_X) ^ (y * _PRIME_Y) ^ (seed_value * _PRIME_S)
	h &= _MASK
	h = (h ^ (h >> 15)) * 0x2545F491
	h &= _MASK
	h = (h ^ (h >> 13)) * 0x27D4EB2D
	return h & _MASK


## Псевдослучайное число в [0, 1) по координатам.
static func value01(x: int, y: int, seed_value: int) -> float:
	return float(hash2i(x, y, seed_value)) / float(_MASK + 1)


## Целое в диапазоне [from, to] включительно.
static func range_int(x: int, y: int, seed_value: int, from: int, to: int) -> int:
	if to <= from:
		return from
	return from + hash2i(x, y, seed_value) % (to - from + 1)


## Готовый к использованию RandomNumberGenerator с заданным сидом.
## Применяется там, где нужна последовательность, а не выборка по координате.
static func stream(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng
