class_name GameSystem
extends RefCounted

## Базовый класс подсистемы симуляции.
##
## Системы выполняются в фиксированном порядке на каждом логическом тике и
## общаются только через контекст и данные мира. Такой контракт позволяет
## добавлять новую систему (электричество, логистика, исследования), не трогая
## цикл симуляции.

var world: GameWorld = null


func setup(game_world: GameWorld) -> void:
	world = game_world
	_on_setup()


func _on_setup() -> void:
	pass


## Один логический тик. `context` содержит grid, registry, daylight и номер тика.
func tick(_delta: float, _context: Dictionary) -> void:
	pass


## Имя для отладочной статистики.
func system_name() -> String:
	return "система"


## Сброс состояния при новой игре или загрузке.
func reset() -> void:
	pass
