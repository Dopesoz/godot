class_name TestCase
extends RefCounted

## Базовый класс для тестов. Никаких сторонних фреймворков: только GDScript.
## Наследник объявляет методы `test_*`, раннер вызывает их по очереди.

var failures: PackedStringArray = PackedStringArray()
var checks: int = 0

var _current: String = ""


func set_current_test(name: String) -> void:
	_current = name


## Вызывается раннером перед каждым тестом.
func before_each() -> void:
	pass


## Вызывается раннером после каждого теста.
func after_each() -> void:
	pass


func check(condition: bool, message: String = "условие не выполнено") -> void:
	checks += 1
	if not condition:
		failures.append("%s: %s" % [_current, message])


func check_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	checks += 1
	if not _values_equal(actual, expected):
		failures.append("%s: ожидалось %s, получено %s%s" % [
			_current, str(expected), str(actual),
			"" if message.is_empty() else " (" + message + ")",
		])


func check_ne(actual: Variant, unexpected: Variant, message: String = "") -> void:
	checks += 1
	if _values_equal(actual, unexpected):
		failures.append("%s: значение не должно равняться %s%s" % [
			_current, str(unexpected), "" if message.is_empty() else " (" + message + ")",
		])


func check_almost(actual: float, expected: float, epsilon: float = 0.0001, message: String = "") -> void:
	checks += 1
	if absf(actual - expected) > epsilon:
		failures.append("%s: ожидалось ~%f, получено %f%s" % [
			_current, expected, actual, "" if message.is_empty() else " (" + message + ")",
		])


func _values_equal(a: Variant, b: Variant) -> bool:
	if typeof(a) == TYPE_FLOAT or typeof(b) == TYPE_FLOAT:
		return is_equal_approx(float(a), float(b))
	return a == b
