extends SceneTree
## Программный снимок игрового мира в PNG.
##
## Headless-режим не рисует на экран, а посмотреть на игру в сборе нужно —
## и при разработке, и для скриншотов в карточку магазина.
##
## Запуск:
##   godot --headless --path drone_factory --script res://tools/render_preview.gd

var done: bool = false


func _process(_delta: float) -> bool:
	if done:
		return true
	done = true
	# Загружаем сборщик в рантайме: главный скрипт компилируется раньше, чем
	# регистрируются автозагрузки, и прямая ссылка на игровые классы там
	# не проходит компиляцию.
	var builder: RefCounted = load("res://tools/preview_builder.gd").new()
	builder.run(self)
	quit(0)
	return true
