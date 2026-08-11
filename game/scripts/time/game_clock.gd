extends Node

## Autoload: GameClock
##
## The only source of time in the game (design doc §17). Needs decay, schedules,
## salaries and the day/night light all read from here, so pausing or speeding
## up the game is a single value change and nothing drifts out of sync.
##
## Everything downstream works in *game minutes*, never in real seconds.

## Total game minutes elapsed since the start of day 0. Single source of truth;
## hour/minute/day are derived from it.
var total_minutes: float = 0.0

var speed_index: int = 1

## Cached integer parts, updated once per frame instead of recomputed by every
## listener.
var minute: int = 0
var hour: int = 7
var day: int = 0

var _last_minute: int = -1
var _last_hour: int = -1
var _last_day: int = -1
var _last_daylight: float = -1.0


func _ready() -> void:
	# Start at 07:00 on day 0 so a new game opens on a waking household.
	total_minutes = 7.0 * GameConstants.MINUTES_PER_HOUR
	_refresh_fields()
	_last_minute = minute
	_last_hour = hour
	_last_day = day


func _process(delta: float) -> void:
	var speed := get_speed()
	if speed <= 0.0:
		return
	advance(delta * GameConstants.GAME_MINUTES_PER_REAL_SECOND * speed)


## Advance the clock by game minutes. Public so that tests and fast-forward
## features can drive time without waiting for real seconds.
func advance(minutes: float) -> void:
	if minutes <= 0.0:
		return
	total_minutes += minutes
	_refresh_fields()
	_emit_boundaries()


func _refresh_fields() -> void:
	var minutes_per_day := GameConstants.MINUTES_PER_HOUR * GameConstants.HOURS_PER_DAY
	var day_minutes := fposmod(total_minutes, float(minutes_per_day))
	day = int(total_minutes / float(minutes_per_day))
	hour = int(day_minutes / float(GameConstants.MINUTES_PER_HOUR))
	minute = int(fmod(day_minutes, float(GameConstants.MINUTES_PER_HOUR)))


## Fires the coarse signals. Listeners that only care about hours never get
## woken 60 times more often than they need — that is the point of the split.
func _emit_boundaries() -> void:
	if minute != _last_minute:
		_last_minute = minute
		EventBus.minute_passed.emit(hour, minute)
	if hour != _last_hour:
		_last_hour = hour
		EventBus.hour_passed.emit(hour)
	if day != _last_day:
		_last_day = day
		EventBus.day_passed.emit(day)
	var light := get_daylight()
	if absf(light - _last_daylight) > 0.01:
		_last_daylight = light
		EventBus.daylight_changed.emit(light)


# --- Queries ----------------------------------------------------------------

## Hour as a float, e.g. 7.5 for 07:30. This is what schedules compare against.
func hour_of_day() -> float:
	var minutes_per_day := GameConstants.MINUTES_PER_HOUR * GameConstants.HOURS_PER_DAY
	return fposmod(total_minutes, float(minutes_per_day)) / float(GameConstants.MINUTES_PER_HOUR)


func day_of_week() -> int:
	return day % GameConstants.DAYS_PER_WEEK


func day_name() -> String:
	return GameConstants.DAY_NAMES[day_of_week()]


## "Mon 07:30" — for the HUD.
func format_time() -> String:
	return "%s %02d:%02d" % [day_name().substr(0, 3), hour, minute]


## 0.0 at night, 1.0 at midday, smoothly interpolated across dawn and dusk.
## Drives outdoor tinting and whether windows glow (design doc §24).
func get_daylight() -> float:
	var h := hour_of_day()
	if h < GameConstants.DAWN_HOUR - 1.0 or h > GameConstants.DUSK_HOUR + 1.0:
		return 0.0
	if h < GameConstants.DAWN_HOUR + 1.0:
		return smoothstep(GameConstants.DAWN_HOUR - 1.0, GameConstants.DAWN_HOUR + 1.0, h)
	if h > GameConstants.DUSK_HOUR - 1.0:
		return 1.0 - smoothstep(GameConstants.DUSK_HOUR - 1.0, GameConstants.DUSK_HOUR + 1.0, h)
	return 1.0


func is_night() -> bool:
	return get_daylight() < 0.25


# --- Speed ------------------------------------------------------------------

func get_speed() -> float:
	return GameConstants.TIME_SPEEDS[clampi(speed_index, 0, GameConstants.TIME_SPEEDS.size() - 1)]


func set_speed_index(index: int) -> void:
	var clamped := clampi(index, 0, GameConstants.TIME_SPEEDS.size() - 1)
	if clamped == speed_index:
		return
	speed_index = clamped
	EventBus.time_speed_changed.emit(speed_index)


func is_paused() -> bool:
	return get_speed() <= 0.0


func toggle_pause() -> void:
	set_speed_index(0 if not is_paused() else 1)


# --- Persistence ------------------------------------------------------------

func save_data() -> Dictionary:
	return {"total_minutes": total_minutes, "speed_index": speed_index}


func load_data(data: Dictionary) -> void:
	total_minutes = float(data.get("total_minutes", 7.0 * GameConstants.MINUTES_PER_HOUR))
	speed_index = int(data.get("speed_index", 1))
	_refresh_fields()
	_last_minute = -1
	_last_hour = -1
	_last_day = -1
	_last_daylight = -1.0
	_emit_boundaries()
