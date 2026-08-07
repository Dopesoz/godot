class_name PixelCanvas
extends RefCounted

## Тонкая обёртка над Image для рисования пиксель-арта в коде.
##
## Вся графика игры генерируется процедурно при старте: в проекте нет ни одного
## растрового ассета. Это даёт крошечный APK, мгновенную загрузку и позволяет
## менять палитру одной правкой.

var image: Image
var width: int
var height: int


func _init(w: int, h: int) -> void:
	width = w
	height = h
	image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	image.fill(Palette.TRANSPARENT)


func fill(color: Color) -> void:
	image.fill(color)


func put(x: int, y: int, color: Color) -> void:
	if x < 0 or y < 0 or x >= width or y >= height:
		return
	if color.a >= 1.0:
		image.set_pixel(x, y, color)
		return
	if color.a <= 0.0:
		return
	image.set_pixel(x, y, image.get_pixel(x, y).blend(color))


func rect(x: int, y: int, w: int, h: int, color: Color) -> void:
	for iy: int in range(y, y + h):
		for ix: int in range(x, x + w):
			put(ix, iy, color)


func rect_outline(x: int, y: int, w: int, h: int, color: Color) -> void:
	for ix: int in range(x, x + w):
		put(ix, y, color)
		put(ix, y + h - 1, color)
	for iy: int in range(y, y + h):
		put(x, iy, color)
		put(x + w - 1, iy, color)


func hline(x: int, y: int, w: int, color: Color) -> void:
	for ix: int in range(x, x + w):
		put(ix, y, color)


func vline(x: int, y: int, h: int, color: Color) -> void:
	for iy: int in range(y, y + h):
		put(x, iy, color)


func line(from: Vector2i, to: Vector2i, color: Color) -> void:
	# Целочисленный Брезенхэм: диагонали остаются «пиксельными», без сглаживания.
	var d: Vector2i = (to - from).abs()
	var step := Vector2i(1 if to.x > from.x else -1, 1 if to.y > from.y else -1)
	var p: Vector2i = from
	var err: int = d.x - d.y
	while true:
		put(p.x, p.y, color)
		if p == to:
			return
		var err2: int = err * 2
		if err2 > -d.y:
			err -= d.y
			p.x += step.x
		if err2 < d.x:
			err += d.x
			p.y += step.y


func circle(cx: int, cy: int, radius: int, color: Color) -> void:
	var r2: int = radius * radius
	for iy: int in range(cy - radius, cy + radius + 1):
		for ix: int in range(cx - radius, cx + radius + 1):
			var dx: int = ix - cx
			var dy: int = iy - cy
			if dx * dx + dy * dy <= r2:
				put(ix, iy, color)


## Случайные точки внутри прямоугольника — «шум» поверхности.
## Плотность 0..1, результат детерминирован сидом.
func speckle(x: int, y: int, w: int, h: int, color: Color, density: float, seed_value: int) -> void:
	for iy: int in range(y, y + h):
		for ix: int in range(x, x + w):
			if Rng.value01(ix, iy, seed_value) < density:
				put(ix, iy, color)


## Пятно неправильной формы: используется для рудных вкраплений.
func blob(cx: int, cy: int, radius: float, color: Color, seed_value: int) -> void:
	var r: int = int(ceilf(radius)) + 1
	for iy: int in range(cy - r, cy + r + 1):
		for ix: int in range(cx - r, cx + r + 1):
			var dx: float = float(ix - cx)
			var dy: float = float(iy - cy)
			var wobble: float = 0.75 + Rng.value01(ix, iy, seed_value) * 0.5
			if sqrt(dx * dx + dy * dy) <= radius * wobble:
				put(ix, iy, color)


## Обводка непрозрачных пикселей (силуэт спрайта) — читаемость на любом фоне.
func outline(color: Color) -> void:
	var source: Image = image.duplicate()
	for y: int in height:
		for x: int in width:
			if source.get_pixel(x, y).a > 0.0:
				continue
			var neighbour: bool = false
			for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + offset.x
				var ny: int = y + offset.y
				if nx < 0 or ny < 0 or nx >= width or ny >= height:
					continue
				if source.get_pixel(nx, ny).a > 0.0:
					neighbour = true
					break
			if neighbour:
				image.set_pixel(x, y, color)


## Зеркальная копия левой половины в правую — симметричные механизмы.
func mirror_horizontal() -> void:
	for y: int in height:
		for x: int in width / 2:
			image.set_pixel(width - 1 - x, y, image.get_pixel(x, y))


func to_texture() -> ImageTexture:
	return ImageTexture.create_from_image(image)
