class_name Log
extends RefCounted

## Простое логирование с уровнями. В релизной сборке (`OS.is_debug_build() == false`)
## отладочные сообщения не печатаются — это заметно экономит время кадра на Android,
## где каждый вывод в logcat стоит дорого.

enum Level { DEBUG, INFO, WARN, ERROR }

static var min_level: Level = Level.DEBUG if OS.is_debug_build() else Level.WARN


static func debug(message: String) -> void:
	if min_level <= Level.DEBUG:
		print("[D] ", message)


static func info(message: String) -> void:
	if min_level <= Level.INFO:
		print("[I] ", message)


static func warn(message: String) -> void:
	if min_level <= Level.WARN:
		push_warning(message)
		print("[W] ", message)


static func error(message: String) -> void:
	push_error(message)
	printerr("[E] ", message)
