extends CanvasModulate

## Tints the whole world by the time of day (design doc §24).
##
## A CanvasModulate covers everything drawn in the world canvas — ground, walls,
## furniture, citizens — in one operation, and leaves the UI alone because the
## interface lives on its own CanvasLayer. That is the cheapest possible
## day/night on a phone: no lights, no shaders, one colour multiply.
##
## Interiors are kept readable by RoomOverlay, which paints a warm pool of light
## into each room after dark, and by windows, which glow instead of dimming.

## Colour the world is multiplied by at full night and full day.
const NIGHT := Color(0.34, 0.40, 0.62)
const DAY := Color(1.0, 1.0, 1.0)
## Sunrise and sunset warmth, mixed in around the transitions.
const GOLDEN := Color(1.0, 0.82, 0.62)

var _shown_daylight: float = -1.0


func _ready() -> void:
	EventBus.daylight_changed.connect(_on_daylight_changed)
	_apply(GameClock.get_daylight())


func _on_daylight_changed(amount: float) -> void:
	_apply(amount)


func _apply(daylight: float) -> void:
	if is_equal_approx(daylight, _shown_daylight):
		return
	_shown_daylight = daylight
	var base := NIGHT.lerp(DAY, daylight)
	# Dawn and dusk are the halfway points, so warmth peaks there and fades out
	# towards both midnight and midday.
	var warmth := 1.0 - absf(daylight - 0.5) * 2.0
	color = base.lerp(GOLDEN, warmth * 0.35)
