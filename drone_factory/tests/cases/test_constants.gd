extends TestCase
## Проверяем инварианты глобальных констант: остальные подсистемы на них опираются.


func test_world_dimensions() -> void:
	check_eq(Constants.WORLD_SIZE, Constants.WORLD_CHUNKS * Constants.CHUNK_SIZE)
	check(Constants.TILE_SIZE > 0, "размер клетки должен быть положительным")
	check(Constants.CHUNK_SIZE > 0, "размер чанка должен быть положительным")


func test_tick_rate() -> void:
	check(Constants.TICKS_PER_SECOND > 0, "частота тика должна быть положительной")
	check_almost(Constants.TICK_DELTA * Constants.TICKS_PER_SECOND, 1.0)
	check(Constants.MAX_CATCHUP_TICKS >= 1, "нужно догонять хотя бы один тик")


func test_camera_zoom_range() -> void:
	check(Constants.CAMERA_ZOOM_MIN < Constants.CAMERA_ZOOM_MAX, "неверный диапазон зума")
	check(
		Constants.CAMERA_ZOOM_DEFAULT >= Constants.CAMERA_ZOOM_MIN
			and Constants.CAMERA_ZOOM_DEFAULT <= Constants.CAMERA_ZOOM_MAX,
		"зум по умолчанию вне диапазона"
	)
