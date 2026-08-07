extends TestCase
## Детерминизм — основа генерации мира и сохранений: один сид обязан давать один мир.


func test_hash_is_deterministic() -> void:
	for i: int in 50:
		var a: int = Rng.hash2i(i, i * 3, 1234)
		var b: int = Rng.hash2i(i, i * 3, 1234)
		check_eq(a, b, "хеш должен быть чистой функцией")


func test_hash_depends_on_all_inputs() -> void:
	check_ne(Rng.hash2i(1, 2, 3), Rng.hash2i(2, 1, 3), "x и y не должны быть взаимозаменяемы")
	check_ne(Rng.hash2i(1, 2, 3), Rng.hash2i(1, 2, 4), "сид должен влиять на результат")


func test_value01_range() -> void:
	for x: int in 40:
		for y: int in 4:
			var v: float = Rng.value01(x * 7 - 100, y * 13, 99)
			check(v >= 0.0 and v < 1.0, "значение %f вне [0,1)" % v)


func test_value01_distribution() -> void:
	# Грубая проверка равномерности: половина значений должна быть выше 0.5.
	var above: int = 0
	var total: int = 2000
	for i: int in total:
		if Rng.value01(i, -i, 7) >= 0.5:
			above += 1
	var ratio: float = float(above) / float(total)
	check(absf(ratio - 0.5) < 0.06, "смещённое распределение: %f" % ratio)


func test_range_int_bounds() -> void:
	for i: int in 200:
		var v: int = Rng.range_int(i, i, 5, 3, 7)
		check(v >= 3 and v <= 7, "значение %d вне [3,7]" % v)
	check_eq(Rng.range_int(0, 0, 0, 4, 4), 4, "вырожденный диапазон")


func test_stream_is_reproducible() -> void:
	var a: RandomNumberGenerator = Rng.stream(42)
	var b: RandomNumberGenerator = Rng.stream(42)
	for i: int in 10:
		check_eq(a.randi(), b.randi(), "поток должен воспроизводиться")
