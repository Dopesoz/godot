extends SceneTree
## Генерация иконок приложения из той же палитры, что и игровая графика.
##
## Запуск:
##   godot --headless --path drone_factory --script res://tools/generate_icons.gd
##
## Файлы кладутся в res://icons и коммитятся: экспорт Android и карточка
## Google Play требуют именно PNG, а собирать их вручную в редакторе — значит
## каждый раз расходиться с палитрой игры.

const OUTPUT_DIR: String = "res://icons"

var done: bool = false


func _process(_delta: float) -> bool:
	if done:
		return true
	done = true

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_save(_draw_icon(true), 192, "icon_192.png")
	_save(_draw_icon(true), 512, "store_512.png")
	# Адаптивная иконка Android: передний план рисуется без фона и с запасом
	# по краям — система обрежет его под форму маски устройства.
	_save(_draw_icon(false, 0.62), 432, "adaptive_foreground_432.png")
	_save(_draw_background(), 432, "adaptive_background_432.png")

	print("Иконки сохранены в ", ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(0)
	return true


func _save(canvas: PixelCanvas, size: int, file_name: String) -> void:
	var image: Image = canvas.image.duplicate()
	image.resize(size, size, Image.INTERPOLATE_NEAREST)
	image.save_png(OUTPUT_DIR.path_join(file_name))


## Иконка: дрон над плитой фабрики. Рисуется в 48x48 и увеличивается
## по-пиксельному, поэтому остаётся чётким на любом экране.
func _draw_icon(with_background: bool, scale_ratio: float = 1.0) -> PixelCanvas:
	var canvas := PixelCanvas.new(48, 48)
	if with_background:
		canvas.fill(Palette.UI_BG)
		canvas.rect(0, 0, 48, 16, Palette.GLASS_DARK.darkened(0.5))

	var inset: int = int(24.0 * (1.0 - scale_ratio))
	# Дрон стоит чуть ниже полосы неба: лопасти на самой границе читались хуже.
	var top: int = 12 + inset / 2

	# Плита фабрики.
	canvas.rect(6 + inset, 30 - inset / 2, 36 - inset * 2, 12, Palette.METAL_DARK)
	canvas.hline(6 + inset, 30 - inset / 2, 36 - inset * 2, Palette.METAL)
	canvas.rect(10 + inset, 33 - inset / 2, 6, 6, Palette.ACCENT)
	canvas.rect(32 - inset, 33 - inset / 2, 6, 6, Palette.ACCENT)

	# Дрон.
	canvas.rect(19, top + 6, 10, 7, Palette.METAL_LIGHT)
	canvas.rect(22, top + 8, 4, 3, Palette.GLASS)
	canvas.hline(11, top + 4, 9, Palette.METAL)
	canvas.hline(28, top + 4, 9, Palette.METAL)
	canvas.vline(15, top + 4, 3, Palette.METAL_DARK)
	canvas.vline(32, top + 4, 3, Palette.METAL_DARK)
	canvas.rect(21, top + 13, 6, 4, Palette.ACCENT)
	canvas.outline(Palette.OUTLINE)
	return canvas


func _draw_background() -> PixelCanvas:
	var canvas := PixelCanvas.new(48, 48)
	canvas.fill(Palette.UI_BG)
	# Лёгкая сетка: фон адаптивной иконки не должен быть плоским пятном.
	for y: int in range(0, 48, 8):
		canvas.hline(0, y, 48, Palette.UI_PANEL)
	for x: int in range(0, 48, 8):
		canvas.vline(x, 0, 48, Palette.UI_PANEL)
	return canvas
