extends TestCase
## Требования Google Play проверяем автоматически: забытый флаг всплывёт
## только при загрузке в консоль, спустя дни после сборки.

const PRESETS_PATH: String = "res://export_presets.cfg"

var config: ConfigFile = null


func before_each() -> void:
	config = ConfigFile.new()
	config.load(PRESETS_PATH)


func preset_names() -> Array[String]:
	var names: Array[String] = []
	for section: String in config.get_sections():
		if section.begins_with("preset.") and not section.ends_with(".options"):
			names.append(String(config.get_value(section, "name", "")))
	return names


func option_sections() -> Array[String]:
	var sections: Array[String] = []
	for section: String in config.get_sections():
		if section.ends_with(".options"):
			sections.append(section)
	return sections


func test_presets_exist() -> void:
	check(FileAccess.file_exists(PRESETS_PATH), "нет файла пресетов экспорта")
	var names: Array[String] = preset_names()
	check(names.size() >= 2, "нужны пресеты и для APK, и для AAB")


func test_arm64_is_enabled() -> void:
	# Google Play не принимает приложения без 64-битной сборки.
	for section: String in option_sections():
		check(bool(config.get_value(section, "architectures/arm64-v8a", false)),
			"%s: не включена arm64-v8a" % section)


func test_min_and_target_sdk() -> void:
	# Уровни SDK переопределяются только при сборке через Gradle: иначе экспорт
	# отказывается собирать проект с внятной ошибкой. Пресет без Gradle обязан
	# оставлять поля пустыми и брать значения из шаблона.
	for section: String in option_sections():
		var gradle: bool = bool(config.get_value(section, "gradle_build/use_gradle_build", false))
		var target: String = String(config.get_value(section, "gradle_build/target_sdk", ""))
		var minimum: String = String(config.get_value(section, "gradle_build/min_sdk", ""))
		if gradle:
			check_eq(target, "34", "%s: целевой API должен соответствовать требованиям Play" % section)
			check(int(minimum) >= 21, "%s: слишком низкий минимальный API" % section)
		else:
			check(target.is_empty() and minimum.is_empty(),
				"%s: без Gradle уровни SDK задавать нельзя — экспорт откажется" % section)


func test_aab_preset_uses_gradle_build() -> void:
	# Формат AAB собирается только через Gradle — иначе экспорт молча даст APK.
	var found: bool = false
	for section: String in option_sections():
		if int(config.get_value(section, "gradle_build/export_format", 0)) == 1:
			found = true
			check(bool(config.get_value(section, "gradle_build/use_gradle_build", false)),
				"AAB требует сборку через Gradle")
	check(found, "нет пресета в формате AAB")


func test_no_unnecessary_permissions() -> void:
	# Лишние разрешения — отдельный раздел в карточке Play и лишние вопросы
	# при модерации. Игра целиком офлайновая.
	for section: String in option_sections():
		for permission: String in [
			"permissions/internet",
			"permissions/access_network_state",
			"permissions/write_external_storage",
		]:
			check(not bool(config.get_value(section, permission, false)),
				"%s: лишнее разрешение %s" % [section, permission])
		var custom: PackedStringArray = config.get_value(section, "permissions/custom_permissions", PackedStringArray())
		check(custom.is_empty(), "%s: заданы дополнительные разрешения" % section)


func test_package_identity() -> void:
	for section: String in option_sections():
		var package: String = String(config.get_value(section, "package/unique_name", ""))
		check(package.contains("."), "%s: некорректное имя пакета: %s" % [section, package])
		check(not package.begins_with("org.godotengine"),
			"%s: имя пакета осталось шаблонным" % section)
		check(int(config.get_value(section, "version/code", 0)) >= 1,
			"%s: код версии должен быть положительным" % section)
		check_eq(
			String(config.get_value(section, "version/name", "")),
			String(ProjectSettings.get_setting("application/config/version", "")),
			"%s: версия в пресете разошлась с версией проекта" % section
		)


func test_icons_exist_and_are_correct_size() -> void:
	var expected: Dictionary[String, int] = {
		"res://icons/icon_192.png": 192,
		"res://icons/adaptive_foreground_432.png": 432,
		"res://icons/adaptive_background_432.png": 432,
		"res://icons/store_512.png": 512,
	}
	for path: String in expected:
		check(FileAccess.file_exists(path), "нет иконки %s" % path)
		var image: Image = Image.load_from_file(path)
		check(image != null, "иконка не читается: %s" % path)
		if image != null:
			check_eq(image.get_width(), expected[path], "неверный размер иконки %s" % path)
			check_eq(image.get_height(), expected[path], "неверный размер иконки %s" % path)


func test_launcher_icons_are_wired() -> void:
	for section: String in option_sections():
		for key: String in [
			"launcher_icons/main_192x192",
			"launcher_icons/adaptive_foreground_432x432",
			"launcher_icons/adaptive_background_432x432",
		]:
			var path: String = String(config.get_value(section, key, ""))
			check(not path.is_empty(), "%s: не задана иконка %s" % [section, key])
			check(FileAccess.file_exists(path), "%s: иконка не найдена: %s" % [section, path])


func test_tests_and_tools_are_excluded() -> void:
	# Тесты и утилиты не должны попадать в магазинную сборку.
	for section: String in config.get_sections():
		if section.begins_with("preset.") and not section.ends_with(".options"):
			var filter: String = String(config.get_value(section, "exclude_filter", ""))
			check(filter.contains("tests/"), "%s: тесты не исключены из сборки" % section)
			check(filter.contains("tools/"), "%s: утилиты не исключены из сборки" % section)


func test_project_is_configured_for_mobile() -> void:
	check_eq(
		String(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile", "")),
		"gl_compatibility",
		"на слабом Android нужен GL Compatibility"
	)
	check_eq(int(ProjectSettings.get_setting("display/window/handheld/orientation", -1)), 1,
		"игра рассчитана на портретную ориентацию")
	check(bool(ProjectSettings.get_setting("rendering/textures/vram_compression/import_etc2_astc", false)),
		"без ETC2/ASTC текстуры на Android займут лишнюю память")
	check_eq(int(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter", -1)), 0,
		"пиксель-арт требует фильтрации «ближайший сосед»")
