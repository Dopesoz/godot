class_name TitleScreen
extends Control

## Заглавный экран: логотип, музыка и вход в игру.
##
## Отдельная сцена, а не панель поверх игры, и на то две причины. Во-первых,
## пока звучит заглавная тема, мир не генерируется и батарея не греется.
## Во-вторых, у игрока появляется честный выбор «продолжить или начать
## заново» до того, как автозагрузка что-нибудь сделает за него.

const GAME_SCENE: String = "res://scenes/main.tscn"
const LOGO_PATH: String = "res://assets/logo.png"
const MUSIC_PATH: String = "res://assets/music/title.mp3"

## Сколько секунд гаснет тема при уходе в игру.
const FADE_SECONDS: float = 0.6

## Где на широком баннере находится сам знак — эмблема с надписью, в долях
## размера картинки.
##
## Баннер горизонтальный, экран телефона вертикальный. Показывать баннер
## целиком значит оставить посреди экрана широкую полосу с собственным фоном,
## которая читается как чужеродная картинка. Поэтому берётся только знак —
## через AtlasTexture, без второго файла в репозитории.
const LOGO_REGION := Rect2(0.352, 0.165, 0.290, 0.680)

var settings: GameSettings = null

var _music: AudioStreamPlayer = null
var _continue_button: Button = null
var _new_game_button: Button = null
var _confirm_new_game: bool = false
var _fade_left: float = 0.0


func _ready() -> void:
	theme = UiTheme.shared()
	settings = GameSettings.new()
	settings.load_settings()

	_build()
	_start_music()


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var source: Texture2D = load(LOGO_PATH)

	var background := ColorRect.new()
	background.name = "Background"
	# Фон берётся из самого баннера: тогда вырезанный знак ложится на экран
	# без видимого шва, даже если логотип когда-нибудь перерисуют.
	background.color = _logo_background(source)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margins: Vector4i = UiTheme.safe_area_margins()
	var holder := MarginContainer.new()
	holder.name = "Holder"
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_theme_constant_override("margin_left", margins.x + UiTheme.PAD_L)
	holder.add_theme_constant_override("margin_right", margins.z + UiTheme.PAD_L)
	holder.add_theme_constant_override("margin_top", margins.y + UiTheme.PAD_L)
	holder.add_theme_constant_override("margin_bottom", margins.w + UiTheme.PAD_L)
	add_child(holder)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", UiTheme.PAD_M)
	holder.add_child(column)

	var logo := TextureRect.new()
	logo.name = "Logo"
	logo.texture = _logo_mark(source)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(logo)

	_continue_button = UiWidgets.text_button("Продолжить", UiTheme.TOUCH_MIN * 4)
	_continue_button.name = "ContinueButton"
	_continue_button.custom_minimum_size.y = UiTheme.TOUCH_LARGE
	_continue_button.visible = SaveSystem.has_save()
	_continue_button.pressed.connect(func() -> void: _launch(false))
	column.add_child(_continue_button)

	_new_game_button = UiWidgets.text_button("Новая игра", UiTheme.TOUCH_MIN * 4)
	_new_game_button.name = "NewGameButton"
	_new_game_button.custom_minimum_size.y = UiTheme.TOUCH_LARGE
	_new_game_button.pressed.connect(_on_new_game)
	column.add_child(_new_game_button)

	var version: Label = UiWidgets.label(
		"Версия %s" % ProjectSettings.get_setting("application/config/version", "?"),
		UiTheme.FONT_SMALL, Palette.UI_TEXT_DIM
	)
	version.name = "Version"
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(version)


## Знак, вырезанный из баннера.
static func _logo_mark(source: Texture2D) -> Texture2D:
	if source == null:
		return null
	var size := Vector2(source.get_width(), source.get_height())
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = Rect2(
		LOGO_REGION.position * size, LOGO_REGION.size * size
	)
	return atlas


## Цвет фона под знаком.
##
## Берётся не из угла баннера, а из угла самой вырезки: у баннера есть лёгкая
## виньетка, и центр там светлее краёв. Цвет угла картинки оставлял вокруг
## знака заметный прямоугольник более светлого фона.
static func _logo_background(source: Texture2D) -> Color:
	if source == null:
		return Palette.UI_BG
	var image: Image = source.get_image()
	if image == null:
		return Palette.UI_BG
	var sample := Vector2i(
		int(LOGO_REGION.position.x * float(image.get_width())) + 2,
		int(LOGO_REGION.position.y * float(image.get_height())) + 2
	)
	sample = sample.clamp(Vector2i.ZERO, image.get_size() - Vector2i.ONE)
	return image.get_pixel(sample.x, sample.y)


## Новая игра поверх сохранения стирает прогресс, поэтому первое нажатие
## только предупреждает — как и в меню внутри игры.
func _on_new_game() -> void:
	if SaveSystem.has_save() and not _confirm_new_game:
		_confirm_new_game = true
		_new_game_button.text = "Точно? Прогресс будет потерян"
		return
	_launch(true)


func _launch(fresh: bool) -> void:
	if _fade_left > 0.0:
		return
	GameLaunch.fresh_start = fresh
	_continue_button.disabled = true
	_new_game_button.disabled = true
	# Тема не обрывается на полуслове: пока она гаснет, сцена ещё живёт.
	_fade_left = FADE_SECONDS


func _process(delta: float) -> void:
	if _fade_left <= 0.0:
		return
	_fade_left -= delta
	if _music != null:
		var ratio: float = clampf(_fade_left / FADE_SECONDS, 0.0, 1.0)
		_music.volume_db = AudioDirector._to_db(music_volume() * ratio)
	if _fade_left <= 0.0:
		get_tree().change_scene_to_file(GAME_SCENE)


func music_volume() -> float:
	return 0.6 if settings == null else settings.music_volume


func _start_music() -> void:
	var stream: AudioStream = load(MUSIC_PATH)
	if stream == null:
		Log.warn("Заглавная тема не загрузилась: %s" % MUSIC_PATH)
		return
	_music = AudioStreamPlayer.new()
	_music.name = "TitleMusic"
	_music.stream = stream
	_music.volume_db = AudioDirector._to_db(music_volume())
	add_child(_music)
	if music_volume() > 0.001:
		_music.play()
