extends SceneTree
## Headless-раннер тестов.
##
## Запуск:
##   godot --headless --path drone_factory --script res://tests/test_runner.gd
##
## Код возврата 0 — все тесты прошли, 1 — есть падения.

const CASES_DIR: String = "res://tests/cases"
## Страховка от зависшего раннера: без неё ошибка разбора скрипта прерывает
## _initialize(), quit() не вызывается и процесс крутится вечно.
const WATCHDOG_SECONDS: float = 600.0

var _elapsed: float = 0.0
var _started: bool = false
var _finished: bool = false


## Тесты запускаются на первом кадре, а не в _initialize(): до первой итерации
## корневое окно ещё не находится в дереве, и добавленные узлы не получают
## _ready() — половина проверок работала бы с недоинициализированными сценами.
func _process(delta: float) -> bool:
	_elapsed += delta
	if not _started:
		_started = true
		_run_all()
		return false
	if not _finished and _elapsed > WATCHDOG_SECONDS:
		printerr("ПАДЕНИЕ: раннер не завершился за %.0f с" % WATCHDOG_SECONDS)
		quit(1)
	return false


func _run_all() -> void:
	var files: PackedStringArray = _list_case_scripts()
	files.sort()

	var total_checks: int = 0
	var total_tests: int = 0
	var all_failures: PackedStringArray = PackedStringArray()

	for path: String in files:
		var script: GDScript = load(path) as GDScript
		if script == null or not script.can_instantiate():
			all_failures.append("%s: скрипт не загружается (ошибка разбора?)" % path)
			continue
		var instance: TestCase = script.new() as TestCase
		if instance == null:
			all_failures.append("%s: скрипт не наследует TestCase" % path)
			continue

		var case_name: String = path.get_file().get_basename()
		for method: Dictionary in script.get_script_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			total_tests += 1
			instance.set_current_test("%s.%s" % [case_name, method_name])
			instance.before_each()
			instance.call(method_name)
			instance.after_each()

		total_checks += instance.checks
		for failure: String in instance.failures:
			all_failures.append(failure)

	_finished = true
	print("")
	print("=== Тесты: %d файлов, %d тестов, %d проверок ===" % [
		files.size(), total_tests, total_checks,
	])
	if all_failures.is_empty():
		print("РЕЗУЛЬТАТ: OK")
		quit(0)
		return

	for failure: String in all_failures:
		printerr("ПАДЕНИЕ: ", failure)
	print("РЕЗУЛЬТАТ: ПАДЕНИЙ %d" % all_failures.size())
	quit(1)


func _list_case_scripts() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(CASES_DIR)
	if dir == null:
		return result
	for file: String in dir.get_files():
		# В экспортированной сборке .gd превращается в .gdc / .remap.
		var name: String = file.trim_suffix(".remap")
		if name.ends_with(".gd") and name.begins_with("test_"):
			result.append(CASES_DIR.path_join(name))
	return result
