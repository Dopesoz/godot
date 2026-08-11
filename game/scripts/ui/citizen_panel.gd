extends PanelContainer

## Inspector for the selected resident: who they are, what they are doing, and
## how their needs are doing.
##
## This is the window onto §34 — "what is going on inside that house?" — so it
## shows the reasoning, not just the numbers: the need currently driving the
## behaviour is highlighted, because that is what explains where the citizen is
## walking.

const REFRESH_SECONDS := 0.25
const BAR_SIZE := Vector2(150, 14)

@onready var _title: Label = %Title
@onready var _subtitle: Label = %Subtitle
@onready var _activity: Label = %Activity
@onready var _needs_box: VBoxContainer = %Needs

var _citizen: Citizen
var _bars: Dictionary = {}
var _timer: float = 0.0


func _ready() -> void:
	visible = false
	EventBus.selection_changed.connect(_on_selection_changed)
	EventBus.citizen_removed.connect(_on_citizen_removed)
	_build_bars()


func _build_bars() -> void:
	for type: int in GameEnums.NeedType.values():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var label := Label.new()
		label.text = String(GameEnums.NeedType.keys()[type]).capitalize()
		label.custom_minimum_size = Vector2(110, 0)
		row.add_child(label)

		var bar := ProgressBar.new()
		bar.custom_minimum_size = BAR_SIZE
		bar.max_value = GameConstants.NEED_MAX
		bar.show_percentage = false
		row.add_child(bar)

		var value := Label.new()
		value.custom_minimum_size = Vector2(40, 0)
		row.add_child(value)

		_needs_box.add_child(row)
		_bars[type] = {"bar": bar, "value": value, "label": label}


func _on_selection_changed(selected: Variant) -> void:
	_citizen = selected as Citizen
	visible = _citizen != null
	if visible:
		_refresh()


func _on_citizen_removed(citizen_id: int) -> void:
	if _citizen != null and _citizen.id == citizen_id:
		_citizen = null
		visible = false


## Polled rather than signal-driven: needs change continuously, and four
## refreshes a second is both enough for the eye and far cheaper than redrawing
## on every simulation tick.
func _process(delta: float) -> void:
	if not visible or _citizen == null:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = REFRESH_SECONDS
		_refresh()


func _refresh() -> void:
	var template := _citizen.data()
	var job := Database.get_job(template.job_id) if template != null and template.job_id != &"" else null
	_title.text = _citizen.citizen_name
	var occupation := job.display_name if job != null else "Unemployed"
	var personality := String(CitizenData.Personality.keys()[template.personality]).capitalize() if template != null else "—"
	var block := _citizen.schedule_label()
	if job != null:
		occupation += "  %02d:00–%02d:00" % [int(job.start_hour), int(job.end_hour)]
		if _citizen.is_on_shift():
			occupation += "  (on shift)"
	_subtitle.text = "%s   •   %s   •   %s   •   earned today $%d" % [
		occupation, personality, block if block != "" else "no routine", _citizen.earned_today]
	# What they are doing and, crucially, why they chose it.
	_activity.text = _citizen.state_name()
	if _citizen.current_reason != "":
		_activity.text += "  —  " + _citizen.current_reason

	var driving := _citizen.lowest_need()
	for type: int in _bars:
		var entry: Dictionary = _bars[type]
		var value := _citizen.need(type)
		var bar: ProgressBar = entry["bar"]
		bar.value = value
		bar.modulate = _colour_for(value)
		(entry["value"] as Label).text = "%d" % roundi(value)
		# The lowest need is the one the citizen is currently acting on.
		(entry["label"] as Label).modulate = (Color(1.0, 0.85, 0.45)
				if type == driving and value <= GameConstants.NEED_URGENT_THRESHOLD
				else Color(1, 1, 1))


static func _colour_for(value: float) -> Color:
	if value <= GameConstants.NEED_URGENT_THRESHOLD * 0.5:
		return Color(1.0, 0.42, 0.38)
	if value <= GameConstants.NEED_URGENT_THRESHOLD:
		return Color(1.0, 0.75, 0.35)
	return Color(0.55, 0.85, 0.55)
