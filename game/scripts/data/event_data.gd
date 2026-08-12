class_name EventData
extends GameData

## Something that happens to the whole city for a while (design doc §11): a
## street festival, a heatwave, a bout of flu.
##
## Events are deliberately *modifiers*, not scripts. An event does not tell
## anyone what to do — it changes the weights everybody is already deciding
## with, exactly like a schedule does for the time of day. A festival makes
## company matter more, and the residents work out the rest themselves: they
## drift towards each other, chat longer, and make friends faster, without a
## single line of festival-specific behaviour.

## Relative chance of being drawn when an event is rolled.
@export_range(0.0, 10.0) var weight: float = 1.0

## How long it lasts, in game hours.
@export var duration_hours: float = 12.0

## Need -> multiplier on how much residents care about it while this is running.
@export var need_weights: Dictionary = {}

## Need -> multiplier on how fast it drains. A heatwave makes hygiene fall
## faster; a quiet weekend makes energy last.
@export var decay_multipliers: Dictionary = {}

## One-off money when it starts: positive for a windfall, negative for a bill.
@export var money_on_start: int = 0
## Per resident, so a bigger city feels the same event proportionally.
@export var money_per_resident: int = 0

## Only fires when the city has at least this many residents — no festivals in
## an empty town.
@export var min_residents: int = 0

## Hours it may start within, same convention as InteractionData.
@export_range(0.0, 24.0) var earliest_hour: float = 0.0
@export_range(0.0, 24.0) var latest_hour: float = 24.0

## Shown in the HUD banner while it runs.
@export var banner_color: Color = Color(0.95, 0.85, 0.55)


func can_start_at(hour: float, residents: int) -> bool:
	if residents < min_residents:
		return false
	if is_equal_approx(earliest_hour, 0.0) and is_equal_approx(latest_hour, 24.0):
		return true
	if earliest_hour < latest_hour:
		return hour >= earliest_hour and hour < latest_hour
	return hour >= earliest_hour or hour < latest_hour
