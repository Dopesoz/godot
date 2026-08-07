class_name UiTheme
extends RefCounted

## Тема интерфейса, собранная кодом.
##
## Никаких .tres и внешних шрифтов: тема строится из той же палитры, что и
## пиксель-арт, поэтому интерфейс и мир выглядят одним целым, а размер APK
## не растёт.
##
## Главное правило мобильной вёрстки здесь — размер цели касания. Всё, во что
## игрок тыкает пальцем, не меньше TOUCH_MIN по короткой стороне: на базовом
## разрешении 720x1280 это примерно 9 мм на типичном телефоне, ниже этого
## промахи становятся систематическими.

## Минимальный размер кнопки в единицах базового разрешения.
const TOUCH_MIN: int = 64
## Крупная кнопка основного действия.
const TOUCH_LARGE: int = 84
## Отступы: используются везде, чтобы интерфейс держал единый ритм.
const PAD_S: int = 6
const PAD_M: int = 12
const PAD_L: int = 20
const RADIUS: int = 8

const FONT_SMALL: int = 20
const FONT_NORMAL: int = 26
const FONT_LARGE: int = 34
const FONT_TITLE: int = 40

## Полупрозрачность панелей: сквозь интерфейс должно быть видно фабрику.
const PANEL_ALPHA: float = 0.94


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = FONT_NORMAL

	_setup_panel(theme)
	_setup_button(theme)
	_setup_label(theme)
	_setup_progress(theme)
	_setup_scroll(theme)
	return theme


## Фон панели с настраиваемым цветом и рамкой.
static func panel_style(
	color: Color = Palette.UI_PANEL,
	border: Color = Palette.UI_PANEL_LIGHT,
	border_width: int = 2
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color, PANEL_ALPHA)
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(RADIUS)
	style.content_margin_left = PAD_M
	style.content_margin_right = PAD_M
	style.content_margin_top = PAD_S
	style.content_margin_bottom = PAD_S
	return style


static func _setup_panel(theme: Theme) -> void:
	theme.set_stylebox("panel", "PanelContainer", panel_style())
	theme.set_stylebox("panel", "Panel", panel_style())


static func _setup_button(theme: Theme) -> void:
	var normal: StyleBoxFlat = panel_style(Palette.UI_PANEL_LIGHT, Palette.METAL, 2)
	var hover: StyleBoxFlat = panel_style(Palette.METAL, Palette.METAL_LIGHT, 2)
	var pressed: StyleBoxFlat = panel_style(Palette.ACCENT_DARK, Palette.ACCENT, 2)
	var disabled: StyleBoxFlat = panel_style(Palette.UI_BG, Palette.UI_PANEL, 2)

	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", hover)
	# На телефоне нет наведения, зато нажатие обязано откликаться мгновенно
	# и заметно: цвет меняется на акцентный.
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("focus", "Button", panel_style(Palette.UI_PANEL_LIGHT, Palette.ACCENT, 2))
	theme.set_stylebox("disabled", "Button", disabled)

	theme.set_color("font_color", "Button", Palette.UI_TEXT)
	theme.set_color("font_pressed_color", "Button", Palette.UI_TEXT)
	theme.set_color("font_hover_color", "Button", Palette.UI_TEXT)
	theme.set_color("font_disabled_color", "Button", Palette.UI_TEXT_DIM)
	theme.set_constant("h_separation", "Button", PAD_S)
	theme.set_font_size("font_size", "Button", FONT_NORMAL)


static func _setup_label(theme: Theme) -> void:
	theme.set_color("font_color", "Label", Palette.UI_TEXT)
	theme.set_font_size("font_size", "Label", FONT_NORMAL)
	theme.set_color("font_color", "RichTextLabel", Palette.UI_TEXT)


static func _setup_progress(theme: Theme) -> void:
	var background: StyleBoxFlat = panel_style(Palette.UI_BG, Palette.UI_PANEL, 1)
	background.content_margin_top = 0
	background.content_margin_bottom = 0
	var fill: StyleBoxFlat = panel_style(Palette.ACCENT, Palette.ACCENT, 0)
	fill.content_margin_top = 0
	fill.content_margin_bottom = 0
	theme.set_stylebox("background", "ProgressBar", background)
	theme.set_stylebox("fill", "ProgressBar", fill)
	theme.set_font_size("font_size", "ProgressBar", FONT_SMALL)
	theme.set_color("font_color", "ProgressBar", Palette.UI_TEXT)


static func _setup_scroll(theme: Theme) -> void:
	# Полосы прокрутки на телефоне не трогают пальцем — делаем их тонкими
	# индикаторами, не отъедающими место у содержимого.
	var grabber: StyleBoxFlat = panel_style(Palette.METAL, Palette.METAL, 0)
	grabber.set_corner_radius_all(3)
	theme.set_stylebox("grabber", "VScrollBar", grabber)
	theme.set_stylebox("grabber_highlight", "VScrollBar", grabber)
	theme.set_stylebox("grabber_pressed", "VScrollBar", grabber)
	theme.set_stylebox("scroll", "VScrollBar", panel_style(Palette.UI_BG, Palette.UI_BG, 0))
	theme.set_stylebox("grabber", "HScrollBar", grabber)
	theme.set_stylebox("grabber_highlight", "HScrollBar", grabber)
	theme.set_stylebox("grabber_pressed", "HScrollBar", grabber)
	theme.set_stylebox("scroll", "HScrollBar", panel_style(Palette.UI_BG, Palette.UI_BG, 0))


## Отступы под вырезы и скруглённые углы экрана. Без этого на телефонах с
## «чёлкой» верхняя панель уезжает под неё.
static func safe_area_margins() -> Vector4i:
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var screen: Vector2i = DisplayServer.screen_get_size()
	if screen.x <= 0 or screen.y <= 0 or safe.size == Vector2i.ZERO:
		return Vector4i(PAD_M, PAD_M, PAD_M, PAD_M)

	# Переводим физические пиксели в единицы базового разрешения.
	var base := Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width", 720)),
		float(ProjectSettings.get_setting("display/window/size/viewport_height", 1280))
	)
	var scale := Vector2(base.x / float(screen.x), base.y / float(screen.y))
	return Vector4i(
		maxi(int(float(safe.position.x) * scale.x), PAD_M),
		maxi(int(float(safe.position.y) * scale.y), PAD_M),
		maxi(int(float(screen.x - safe.end.x) * scale.x), PAD_M),
		maxi(int(float(screen.y - safe.end.y) * scale.y), PAD_M)
	)
