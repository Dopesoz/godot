extends TestCase
## Камера — половина ощущений от мобильной игры: проверяем границы, зум и инерцию.

const VIEW := Vector2(720, 1280)

var camera: GameCamera = null


func before_each() -> void:
	camera = GameCamera.new()
	camera.view_size_override = VIEW
	Engine.get_main_loop().root.add_child(camera)
	camera.set_zoom_level(2.0, false)
	camera.focus_on_cell(Vector2i(Constants.WORLD_SIZE / 2, Constants.WORLD_SIZE / 2))


func after_each() -> void:
	if is_instance_valid(camera):
		camera.free()
	camera = null


func test_pan_moves_opposite_to_finger() -> void:
	var before: Vector2 = camera.position
	# Палец тянет карту вправо — камера уезжает влево, карта следует за пальцем.
	camera.pan_by_screen(Vector2(100, 0))
	check(camera.position.x < before.x, "карта должна следовать за пальцем")
	check_almost(camera.position.x, before.x - 50.0, 0.01, "сдвиг делится на зум")


func test_pan_is_scaled_by_zoom() -> void:
	camera.set_zoom_level(1.0, false)
	var before: Vector2 = camera.position
	camera.pan_by_screen(Vector2(100, 0))
	var far_delta: float = absf(camera.position.x - before.x)

	camera.set_zoom_level(4.0, false)
	before = camera.position
	camera.pan_by_screen(Vector2(100, 0))
	var near_delta: float = absf(camera.position.x - before.x)

	check(far_delta > near_delta, "при приближении тот же жест должен двигать меньше")


func test_zoom_is_clamped() -> void:
	for i: int in 40:
		camera.zoom_at(1.5, VIEW * 0.5)
	check_almost(camera.get_zoom_level(), Constants.CAMERA_ZOOM_MAX, 0.01, "верхний предел зума")
	for i: int in 40:
		camera.zoom_at(0.5, VIEW * 0.5)
	check_almost(camera.get_zoom_level(), Constants.CAMERA_ZOOM_MIN, 0.01, "нижний предел зума")


func test_zoom_keeps_point_under_fingers() -> void:
	var screen_point := Vector2(200, 900)
	var world_before: Vector2 = camera.screen_to_world(screen_point)
	camera.zoom_at(1.6, screen_point)
	var world_after: Vector2 = camera.screen_to_world(screen_point)
	check(
		world_before.distance_to(world_after) < 0.5,
		"точка под пальцами уехала на %.2f px" % world_before.distance_to(world_after)
	)


func test_screen_world_round_trip() -> void:
	for point: Vector2 in [Vector2.ZERO, VIEW * 0.5, VIEW, Vector2(123, 456)]:
		var back: Vector2 = camera.world_to_screen(camera.screen_to_world(point))
		check(back.distance_to(point) < 0.01, "преобразование координат не обратимо в %s" % point)


func test_camera_stays_inside_world() -> void:
	var world_px: float = float(Constants.WORLD_SIZE * Constants.TILE_SIZE)
	camera.set_zoom_level(1.0, false)

	for i: int in 200:
		camera.pan_by_screen(Vector2(-200, -200))
	var rect: Rect2 = camera.visible_world_rect()
	check(rect.end.x <= world_px + 0.01, "камера ушла за правый край: %f" % rect.end.x)
	check(rect.end.y <= world_px + 0.01, "камера ушла за нижний край: %f" % rect.end.y)

	for i: int in 400:
		camera.pan_by_screen(Vector2(200, 200))
	rect = camera.visible_world_rect()
	check(rect.position.x >= -0.01, "камера ушла за левый край: %f" % rect.position.x)
	check(rect.position.y >= -0.01, "камера ушла за верхний край: %f" % rect.position.y)


func test_visible_rect_matches_zoom() -> void:
	camera.set_zoom_level(2.0, false)
	var rect: Rect2 = camera.visible_world_rect()
	check_almost(rect.size.x, VIEW.x / 2.0, 0.01)
	check_almost(rect.size.y, VIEW.y / 2.0, 0.01)


func test_fling_decays_and_stops() -> void:
	camera.fling(Vector2(600, 0))
	check(camera.is_moving(), "после броска камера должна двигаться")
	var moved: bool = false
	var previous: Vector2 = camera.position
	for i: int in 200:
		camera._process(1.0 / 60.0)
		if camera.position != previous:
			moved = true
		previous = camera.position
	check(moved, "бросок не сдвинул камеру")
	check(not camera.is_moving(), "инерция должна затухать")


func test_stop_inertia() -> void:
	camera.fling(Vector2(600, 600))
	camera.stop_inertia()
	var before: Vector2 = camera.position
	camera._process(0.1)
	check_eq(camera.position, before, "касание должно немедленно останавливать карту")


func test_zoom_smoothing_reaches_target() -> void:
	camera.set_zoom_level(1.0, false)
	camera.set_zoom_level(3.0, true)
	check_ne(camera.get_zoom_level(), 3.0, "плавный зум не должен срабатывать мгновенно")
	for i: int in 200:
		camera._process(1.0 / 60.0)
	check_almost(camera.get_zoom_level(), 3.0, 0.01, "плавный зум должен дойти до цели")


func test_screen_to_cell() -> void:
	camera.set_zoom_level(1.0, false)
	var center_cell: Vector2i = camera.screen_to_cell(VIEW * 0.5)
	check_eq(center_cell, Grid.world_to_cell(camera.position), "центр экрана — клетка под камерой")
