class_name GameCamera
extends Camera2D

## Камера мобильной карты: перетаскивание с инерцией, зум щипком, жёсткие
## границы мира.
##
## Камера ничего не знает о вводе — ей отдают готовые команды (сдвинуть,
## приблизить). Так один и тот же код работает и с пальцем, и с мышью,
## и в тестах.

## Замедление инерции: доля скорости, теряемая за секунду.
const FRICTION: float = 6.0
## Ниже этой скорости (px/с в мировых координатах) инерция гасится.
const MIN_FLING_SPEED: float = 8.0
## Скорость подтягивания текущего зума к целевому.
const ZOOM_SMOOTHING: float = 14.0

## Размер вьюпорта для расчётов. Пустой вектор — брать у вьюпорта.
var view_size_override: Vector2 = Vector2.ZERO

var target_zoom: float = Constants.CAMERA_ZOOM_DEFAULT

var _velocity: Vector2 = Vector2.ZERO
var _world_bounds: Rect2 = Rect2(
	Vector2.ZERO,
	Vector2.ONE * float(Constants.WORLD_SIZE * Constants.TILE_SIZE)
)


func _ready() -> void:
	zoom = Vector2.ONE * Constants.CAMERA_ZOOM_DEFAULT
	target_zoom = Constants.CAMERA_ZOOM_DEFAULT
	position_smoothing_enabled = false
	ignore_rotation = true
	make_current()


func _process(delta: float) -> void:
	_apply_zoom_smoothing(delta)
	_apply_inertia(delta)


## --- Команды ---------------------------------------------------------------

## Сдвиг пальцем: смещение в экранных пикселях переводится в мировые.
func pan_by_screen(delta_screen: Vector2) -> void:
	position -= delta_screen / zoom.x
	_clamp_position()


## Бросок: палец отпущен на скорости. Скорость задаётся в экранных px/с.
func fling(velocity_screen: Vector2) -> void:
	_velocity = -velocity_screen / zoom.x


func stop_inertia() -> void:
	_velocity = Vector2.ZERO


## Зум щипком вокруг точки экрана: точка под пальцами остаётся на месте.
func zoom_at(factor: float, screen_point: Vector2) -> void:
	var before: Vector2 = screen_to_world(screen_point)
	target_zoom = clampf(
		target_zoom * factor, Constants.CAMERA_ZOOM_MIN, Constants.CAMERA_ZOOM_MAX
	)
	zoom = Vector2.ONE * target_zoom
	var after: Vector2 = screen_to_world(screen_point)
	position += before - after
	_clamp_position()


## Мгновенно установить зум (кнопки интерфейса, загрузка сохранения).
func set_zoom_level(level: float, smooth: bool = true) -> void:
	target_zoom = clampf(level, Constants.CAMERA_ZOOM_MIN, Constants.CAMERA_ZOOM_MAX)
	if not smooth:
		zoom = Vector2.ONE * target_zoom
		_clamp_position()


func get_zoom_level() -> float:
	return zoom.x


func focus_on_cell(cell: Vector2i) -> void:
	position = Grid.cell_to_world_center(cell)
	_velocity = Vector2.ZERO
	_clamp_position()


## --- Запросы ---------------------------------------------------------------

func view_size() -> Vector2:
	if view_size_override != Vector2.ZERO:
		return view_size_override
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return Vector2(720, 1280)
	return viewport.get_visible_rect().size


## Видимая часть мира в пикселях — по ней стримятся чанки.
func visible_world_rect() -> Rect2:
	var size: Vector2 = view_size() / zoom.x
	return Rect2(position - size * 0.5, size)


func screen_to_world(screen_point: Vector2) -> Vector2:
	return position + (screen_point - view_size() * 0.5) / zoom.x


func world_to_screen(world_point: Vector2) -> Vector2:
	return (world_point - position) * zoom.x + view_size() * 0.5


func screen_to_cell(screen_point: Vector2) -> Vector2i:
	return Grid.world_to_cell(screen_to_world(screen_point))


func is_moving() -> bool:
	return _velocity.length() > MIN_FLING_SPEED or not is_equal_approx(zoom.x, target_zoom)


## --- Внутреннее ------------------------------------------------------------

func _apply_zoom_smoothing(delta: float) -> void:
	if is_equal_approx(zoom.x, target_zoom):
		return
	var next: float = lerpf(zoom.x, target_zoom, minf(ZOOM_SMOOTHING * delta, 1.0))
	if absf(next - target_zoom) < 0.001:
		next = target_zoom
	zoom = Vector2.ONE * next
	_clamp_position()


func _apply_inertia(delta: float) -> void:
	if _velocity.length() <= MIN_FLING_SPEED:
		_velocity = Vector2.ZERO
		return
	position += _velocity * delta
	_velocity *= maxf(1.0 - FRICTION * delta, 0.0)
	_clamp_position()


## Камера не должна показывать пустоту за краем мира: центр ограничивается
## так, чтобы видимая область оставалась внутри. Если мир меньше экрана —
## центрируем по миру.
func _clamp_position() -> void:
	var half: Vector2 = view_size() / zoom.x * 0.5
	var min_pos: Vector2 = _world_bounds.position + half
	var max_pos: Vector2 = _world_bounds.end - half

	if min_pos.x > max_pos.x:
		position.x = _world_bounds.get_center().x
	else:
		position.x = clampf(position.x, min_pos.x, max_pos.x)

	if min_pos.y > max_pos.y:
		position.y = _world_bounds.get_center().y
	else:
		position.y = clampf(position.y, min_pos.y, max_pos.y)

	# У края инерцию гасим, иначе камера «упирается» и продолжает дрожать.
	if is_equal_approx(position.x, min_pos.x) or is_equal_approx(position.x, max_pos.x):
		_velocity.x = 0.0
	if is_equal_approx(position.y, min_pos.y) or is_equal_approx(position.y, max_pos.y):
		_velocity.y = 0.0
