extends TestCase
## Заглавный экран: логотип, тема и вход в игру.

var screen: TitleScreen = null


func before_each() -> void:
	SaveSystem.delete_save()
	GameLaunch.fresh_start = false
	screen = TitleScreen.new()
	Engine.get_main_loop().root.add_child(screen)


func after_each() -> void:
	if is_instance_valid(screen):
		screen.free()
	screen = null
	GameLaunch.fresh_start = false
	SaveSystem.delete_save()


func button(name: String) -> Button:
	return screen.find_child(name, true, false) as Button


func test_assets_are_present() -> void:
	# Логотип и тема — файлы, а не процедурная графика: если их потеряют при
	# переносе проекта, экран должен падать здесь, а не у игрока.
	var logo: Texture2D = load(TitleScreen.LOGO_PATH)
	check(logo != null, "логотип не загрузился")
	check(logo.get_width() > 256, "логотип подозрительно мелкий")

	var music: AudioStream = load(TitleScreen.MUSIC_PATH)
	check(music != null, "заглавная тема не загрузилась")
	check(music.get_length() > 20.0, "тема короче двадцати секунд: %.1f" % music.get_length())


func test_logo_is_shown() -> void:
	var logo: TextureRect = screen.find_child("Logo", true, false) as TextureRect
	check(logo != null, "на заглавном экране должен быть логотип")
	check(logo.texture != null, "логотипу не досталась картинка")


func test_continue_appears_only_with_a_save() -> void:
	check(
		not button("ContinueButton").visible,
		"без сохранения продолжать нечего"
	)

	# Второй экран уже с сохранением на диске.
	var file: FileAccess = FileAccess.open(Constants.SAVE_FILE, FileAccess.WRITE)
	if file != null:
		file.store_string("{}")
		file.close()
	var second := TitleScreen.new()
	Engine.get_main_loop().root.add_child(second)
	check(
		(second.find_child("ContinueButton", true, false) as Button).visible,
		"с сохранением должна появиться кнопка «Продолжить»"
	)
	second.free()


func test_continue_does_not_ask_for_a_fresh_start() -> void:
	button("ContinueButton").pressed.emit()
	check(not GameLaunch.fresh_start, "продолжение не должно стирать партию")


func test_new_game_without_save_starts_immediately() -> void:
	button("NewGameButton").pressed.emit()
	check(GameLaunch.fresh_start, "без сохранения подтверждать нечего")


func test_new_game_over_a_save_asks_twice() -> void:
	var file: FileAccess = FileAccess.open(Constants.SAVE_FILE, FileAccess.WRITE)
	if file != null:
		file.store_string("{}")
		file.close()
	var second := TitleScreen.new()
	Engine.get_main_loop().root.add_child(second)
	var new_game: Button = second.find_child("NewGameButton", true, false) as Button

	new_game.pressed.emit()
	check(not GameLaunch.fresh_start, "первое нажатие обязано только предупредить")
	check(new_game.text.contains("Точно"), "предупреждение должно быть видно на кнопке")

	new_game.pressed.emit()
	check(GameLaunch.fresh_start, "второе нажатие начинает новую партию")
	second.free()


func test_launch_intent_is_read_once() -> void:
	GameLaunch.fresh_start = true
	check(GameLaunch.take_fresh_start(), "намерение должно считаться")
	check(
		not GameLaunch.take_fresh_start(),
		"повторный запуск игры не должен неожиданно стирать прогресс"
	)
