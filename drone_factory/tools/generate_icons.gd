extends SceneTree
## Иконки приложения из логотипа игры.
##
## Запуск:
##   godot --headless --path drone_factory --script res://tools/generate_icons.gd
##
## Файлы кладутся в res://icons и коммитятся: экспорт Android и карточка
## Google Play требуют именно PNG.
##
## Логотип — широкий баннер, а иконка обязана быть квадратной, поэтому из него
## вырезается эмблема-шестерня. Границы вырезки заданы долями от размера
## картинки, а не пикселями: если баннер когда-нибудь переснимут в другом
## разрешении, пропорции останутся верными.

const OUTPUT_DIR: String = "res://icons"
const LOGO_PATH: String = "res://assets/logo.png"

## Где на баннере находится эмблема: центр и сторона квадрата в долях ширины.
const EMBLEM_CENTER := Vector2(0.503, 0.397)
const EMBLEM_SIZE: float = 0.238

## Фон адаптивной иконки: тот же тёмный, что и у баннера.
const BACKGROUND := Color8(30, 35, 42)

var done: bool = false


func _process(_delta: float) -> bool:
	if done:
		return true
	done = true

	var logo: Image = _load_logo()
	if logo == null:
		quit(1)
		return true

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var emblem: Image = _crop_emblem(logo)

	_save(_on_background(emblem, 192), "icon_192.png")
	_save(_on_background(emblem, 512), "store_512.png")
	# Адаптивная иконка: передний план без фона и с запасом по краям — систему
	# устройства не волнует наша композиция, она обрежет его своей маской.
	_save(_adaptive_foreground(emblem, 432), "adaptive_foreground_432.png")
	_save(_solid(432, BACKGROUND), "adaptive_background_432.png")

	print("Иконки собраны из логотипа в ", ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(0)
	return true


func _load_logo() -> Image:
	var texture: Texture2D = load(LOGO_PATH)
	if texture == null:
		push_error("Логотип не найден: " + LOGO_PATH)
		return null
	return texture.get_image()


## Квадрат с эмблемой из широкого баннера.
func _crop_emblem(logo: Image) -> Image:
	var side: int = int(float(logo.get_width()) * EMBLEM_SIZE)
	var centre := Vector2i(
		int(float(logo.get_width()) * EMBLEM_CENTER.x),
		int(float(logo.get_height()) * EMBLEM_CENTER.y)
	)
	var region := Rect2i(centre - Vector2i(side, side) / 2, Vector2i(side, side))
	region = region.intersection(Rect2i(Vector2i.ZERO, logo.get_size()))
	return logo.get_region(region)


func _on_background(emblem: Image, size: int) -> Image:
	var target: Image = _solid(size, BACKGROUND)
	var scaled: Image = emblem.duplicate()
	scaled.resize(size, size, Image.INTERPOLATE_LANCZOS)
	scaled.convert(Image.FORMAT_RGBA8)
	target.blend_rect(scaled, Rect2i(Vector2i.ZERO, scaled.get_size()), Vector2i.ZERO)
	return target


## Эмблема с полями и круглой маской: за пределами шестерни фон баннера
## всё равно есть, и без маски он вылезал бы прямоугольником из-под формы.
func _adaptive_foreground(emblem: Image, size: int) -> Image:
	var inner: int = int(float(size) * 0.66)
	var scaled: Image = emblem.duplicate()
	scaled.resize(inner, inner, Image.INTERPOLATE_LANCZOS)
	scaled.convert(Image.FORMAT_RGBA8)

	var radius: float = float(inner) * 0.5
	var centre := Vector2(radius, radius)
	for y: int in inner:
		for x: int in inner:
			var distance: float = Vector2(float(x), float(y)).distance_to(centre)
			if distance <= radius - 1.0:
				continue
			var colour: Color = scaled.get_pixel(x, y)
			# Мягкий край: резкая граница круга на иконке выглядит как брак.
			colour.a = clampf(radius - distance, 0.0, 1.0)
			scaled.set_pixel(x, y, colour)

	var target: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	target.fill(Color(0, 0, 0, 0))
	target.blend_rect(
		scaled, Rect2i(Vector2i.ZERO, scaled.get_size()),
		Vector2i(size - inner, size - inner) / 2
	)
	return target


func _solid(size: int, colour: Color) -> Image:
	var image: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(colour)
	return image


func _save(image: Image, file_name: String) -> void:
	image.save_png(OUTPUT_DIR.path_join(file_name))
