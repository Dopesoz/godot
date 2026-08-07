extends TestCase
## Жесты — единственный способ игрока говорить с игрой, поэтому проверяем
## каждый из них отдельно и на «ложные срабатывания» тоже.

const VIEW := Vector2(720, 1280)

var camera: GameCamera = null
var input: TouchInput = null
var taps: Array[Vector2] = []
var long_presses: Array[Vector2] = []
var drag_events: PackedStringArray = PackedStringArray()


func before_each() -> void:
	camera = GameCamera.new()
	camera.view_size_override = VIEW
	Engine.get_main_loop().root.add_child(camera)
	camera.set_zoom_level(2.0, false)
	camera.focus_on_cell(Vector2i(Constants.WORLD_SIZE / 2, Constants.WORLD_SIZE / 2))

	input = TouchInput.new()
	input.camera = camera
	Engine.get_main_loop().root.add_child(input)

	taps = []
	long_presses = []
	drag_events = PackedStringArray()
	input.tapped.connect(func(position: Vector2) -> void: taps.append(position))
	input.long_pressed.connect(func(position: Vector2) -> void: long_presses.append(position))
	input.drag_started.connect(func() -> void: drag_events.append("start"))
	input.drag_ended.connect(func() -> void: drag_events.append("end"))


func after_each() -> void:
	if is_instance_valid(input):
		input.free()
	if is_instance_valid(camera):
		camera.free()
	input = null
	camera = null


## --- Помощники -------------------------------------------------------------

func press(position: Vector2, index: int = 0) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = true
	input.handle_event(event)


func release(position: Vector2, index: int = 0) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = false
	input.handle_event(event)


func drag(to: Vector2, relative: Vector2, index: int = 0, velocity: Vector2 = Vector2.ZERO) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = to
	event.relative = relative
	event.velocity = velocity
	input.handle_event(event)


func advance(seconds: float) -> void:
	var steps: int = maxi(1, int(seconds / 0.016))
	for i: int in steps:
		input._process(seconds / float(steps))


## --- Тесты -----------------------------------------------------------------

func test_tap_is_reported() -> void:
	var point := Vector2(300, 700)
	press(point)
	advance(0.08)
	release(point)
	check_eq(taps.size(), 1, "тап не распознан")
	check_eq(taps[0], point)
	check_eq(drag_events.size(), 0, "тап не должен считаться перетаскиванием")


func test_short_drag_below_threshold_is_still_a_tap() -> void:
	# Палец всегда немного смещается: несколько пикселей не должны ломать тап.
	press(Vector2(300, 700))
	drag(Vector2(304, 703), Vector2(4, 3))
	advance(0.05)
	release(Vector2(304, 703))
	check_eq(taps.size(), 1, "дрожание пальца не должно отменять тап")


func test_drag_pans_camera_and_suppresses_tap() -> void:
	var before: Vector2 = camera.position
	press(Vector2(300, 700))
	for i: int in 5:
		drag(Vector2(300 - (i + 1) * 20, 700), Vector2(-20, 0))
	release(Vector2(200, 700))

	check(camera.position.x > before.x, "карта не сдвинулась")
	check_eq(taps.size(), 0, "перетаскивание не должно давать тап")
	check_eq(drag_events.size(), 2, "должны прийти начало и конец перетаскивания")
	check_eq(drag_events[0], "start")


func test_fling_gives_camera_inertia() -> void:
	press(Vector2(300, 900))
	for i: int in 4:
		drag(Vector2(300, 900 - (i + 1) * 30), Vector2(0, -30), 0, Vector2(0, -1800))
	release(Vector2(300, 780))
	check(camera.is_moving(), "после броска карта должна продолжать движение")


func test_long_press_is_reported_once() -> void:
	press(Vector2(400, 800))
	advance(Constants.TOUCH_LONG_PRESS_TIME + 0.1)
	check_eq(long_presses.size(), 1, "долгое нажатие не сработало")
	advance(0.5)
	check_eq(long_presses.size(), 1, "долгое нажатие не должно повторяться")
	release(Vector2(400, 800))
	check_eq(taps.size(), 0, "после долгого нажатия тап не выдаётся")


func test_long_press_cancelled_by_movement() -> void:
	press(Vector2(400, 800))
	drag(Vector2(500, 800), Vector2(100, 0))
	advance(Constants.TOUCH_LONG_PRESS_TIME + 0.1)
	check_eq(long_presses.size(), 0, "при перетаскивании долгого нажатия быть не должно")


func test_double_tap_zooms_in() -> void:
	var before: float = camera.get_zoom_level()
	var point := Vector2(360, 640)
	press(point)
	advance(0.05)
	release(point)
	advance(0.05)
	press(point)
	advance(0.03)
	release(point)
	check(camera.get_zoom_level() > before, "двойной тап должен приближать")


func test_double_tap_drag_zooms_without_panning() -> void:
	var point := Vector2(360, 640)
	press(point)
	advance(0.05)
	release(point)
	advance(0.05)

	var position_before: Vector2 = camera.position
	var zoom_before: float = camera.get_zoom_level()
	press(point)
	drag(point + Vector2(0, -120), Vector2(0, -120))
	check(camera.get_zoom_level() > zoom_before, "протяжка вверх должна приближать")
	drag(point + Vector2(0, 120), Vector2(0, 240))
	check(camera.get_zoom_level() < zoom_before * 1.01, "протяжка вниз должна отдалять")
	release(point + Vector2(0, 120))
	check_eq(taps.size(), 1, "второе касание двойного тапа не выдаёт отдельный тап")
	# Небольшой сдвиг центра при зуме к точке допустим, но карта не должна «уезжать».
	check(
		camera.position.distance_to(position_before) < 200.0,
		"зум одним пальцем не должен превращаться в панораму"
	)


func test_slow_second_tap_is_a_normal_tap() -> void:
	var point := Vector2(360, 640)
	press(point)
	release(point)
	advance(TouchInput.DOUBLE_TAP_TIME + 0.1)
	var zoom_before: float = camera.get_zoom_level()
	press(point)
	release(point)
	check_eq(taps.size(), 2, "оба касания должны быть обычными тапами")
	check_almost(camera.get_zoom_level(), zoom_before, 0.001, "медленный повтор не приближает")


func test_pinch_zooms() -> void:
	var zoom_before: float = camera.get_zoom_level()
	press(Vector2(300, 600), 0)
	press(Vector2(400, 600), 1)
	drag(Vector2(250, 600), Vector2(-50, 0), 0)
	drag(Vector2(450, 600), Vector2(50, 0), 1)
	check(camera.get_zoom_level() > zoom_before, "разведение пальцев должно приближать")

	var zoom_middle: float = camera.get_zoom_level()
	drag(Vector2(340, 600), Vector2(90, 0), 0)
	drag(Vector2(360, 600), Vector2(-90, 0), 1)
	check(camera.get_zoom_level() < zoom_middle, "сведение пальцев должно отдалять")

	release(Vector2(340, 600), 0)
	release(Vector2(360, 600), 1)
	check_eq(taps.size(), 0, "щипок не должен превращаться в тап")


func test_disabled_input_is_ignored() -> void:
	input.enabled = false
	var before: Vector2 = camera.position
	press(Vector2(300, 700))
	drag(Vector2(200, 700), Vector2(-100, 0))
	release(Vector2(200, 700))
	check_eq(taps.size(), 0, "выключенный ввод не должен давать событий")
	check_eq(camera.position, before, "выключенный ввод не должен двигать камеру")


func test_cancel_resets_gesture() -> void:
	press(Vector2(300, 700))
	drag(Vector2(200, 700), Vector2(-100, 0))
	check(input.is_gesture_active(), "жест должен быть активен")
	input.cancel()
	check(not input.is_gesture_active(), "cancel() обязан сбросить состояние")
	release(Vector2(200, 700))
	check_eq(taps.size(), 0, "после отмены событий быть не должно")


func test_touch_stops_camera_inertia() -> void:
	camera.fling(Vector2(800, 0))
	check(camera.is_moving())
	press(Vector2(300, 700))
	check(not camera.is_moving(), "касание должно останавливать летящую карту")
