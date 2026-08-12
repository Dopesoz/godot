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
@onready var _skills_box: VBoxContainer = %Skills
@onready var _relations_label: Label = %Relations

var _citizen: Citizen
var _bars: Dictionary = {}
var _skill_rows: Dictionary = {}
var _timer: float = 0.0


func _ready() -> void:
	visible = false
	UiTheme.apply(self)
	_apply_mobile_layout()
	EventBus.selection_changed.connect(_on_selection_changed)
	EventBus.citizen_removed.connect(_on_citizen_removed)
	_build_bars()
	_build_skill_rows()


## On a phone there is no Escape key and no second mouse button, so the panel
## needs a visible way to close, and it narrows so it does not cover the house
## the player is watching.
func _apply_mobile_layout() -> void:
	var close := Button.new()
	close.text = "×"
	close.custom_minimum_size = Vector2(44, 44) * Platform.ui_scale()
	close.flat = true
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func() -> void: EventBus.selection_changed.emit(null))
	%Title.get_parent().add_child(close)
	%Title.get_parent().move_child(close, 0)

	if not Platform.has_touch():
		return
	var margins := Platform.safe_area_margins()
	offset_right -= float(margins.z)
	offset_left = minf(offset_left + float(margins.z), -220.0)
	_scale_for_touch()


## Everything a phone needs that a desktop does not, in one place.
##
## Text: the panel was drawn at desktop size next to a HUD twice that big —
## it looks like a bug and reads like fine print at arm's length.
##
## Height: the panel is anchored to the middle of the right edge and the build
## bar is twice as tall on a phone, so the bottom of the panel — relationships,
## the thing that makes residents people rather than meters — sat underneath it.
##
## The fix for the height is not to shrink the content but to let it scroll. The
## contents are wrapped in a ScrollContainer at runtime, which stops the panel
## from being sized by its own text, so the offsets below actually hold and the
## panel can simply stop where the bar begins.
func _scale_for_touch() -> void:
	var scale := maxf(Platform.ui_scale() * 0.75, 1.0)
	for label: Label in [_title, _subtitle, _activity, _relations_label]:
		var base := label.get_theme_font_size(&"font_size")
		label.add_theme_font_size_override(&"font_size", roundi(float(base) * scale))

	var layout := get_child(0) as Control
	if layout != null:
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		remove_child(layout)
		add_child(scroll)
		scroll.add_child(layout)
		layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var viewport := get_viewport_rect().size
	offset_left = -minf(340.0 * scale, viewport.x * 0.45)
	# Below the clock, above the build bar. Both are measured rather than
	# assumed, because both change size with the screen.
	var top := 96.0 * scale
	var bottom := viewport.y - float(Platform.safe_area_margins().w) - 8.0
	var bar := get_parent().get_node_or_null("BuildBar") as Control
	if bar != null:
		bottom = minf(bottom, bar.get_global_rect().position.y - 8.0)
	# The panel is anchored to the middle of the right edge, so its offsets are
	# measured from the centre of the screen.
	offset_top = top - viewport.y * 0.5
	offset_bottom = maxf(bottom - viewport.y * 0.5, offset_top + 240.0)


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


## One row per skill, hidden until the citizen has actually practised it — a
## wall of six empty bars says nothing, while "Cooking 3" says who this is.
func _build_skill_rows() -> void:
	for skill in Database.all_skills():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var label := Label.new()
		label.text = skill.display_name
		label.custom_minimum_size = Vector2(110, 0)
		label.modulate = skill.icon_color
		row.add_child(label)

		var bar := ProgressBar.new()
		bar.custom_minimum_size = BAR_SIZE
		bar.max_value = 1.0
		bar.step = 0.01
		bar.show_percentage = false
		row.add_child(bar)

		var level := Label.new()
		level.custom_minimum_size = Vector2(40, 0)
		row.add_child(level)

		_skills_box.add_child(row)
		_skill_rows[skill.id] = {"row": row, "bar": bar, "level": level}


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
	var home := "no fixed address"
	var world := get_tree().get_first_node_in_group(&"world")
	if world != null and _citizen.household_id != -1:
		var registry := world.get_node_or_null("Households") as HouseholdRegistry
		var household := registry.get_household(_citizen.household_id) if registry != null else null
		if household != null:
			home = "%s, savings $%d" % [household.label(), household.savings]
	_subtitle.text = "%s   •   %s   •   %s   •   %s   •   today $%d" % [
		occupation, personality, block if block != "" else "no routine", home, _citizen.earned_today]
	# What they are doing and, crucially, why they chose it.
	_activity.text = _citizen.state_name()
	if _citizen.current_reason != "":
		_activity.text += "  —  " + _citizen.current_reason

	for skill_id: StringName in _skill_rows:
		var skill := Database.get_skill(skill_id)
		var entry: Dictionary = _skill_rows[skill_id]
		var xp := _citizen.skill_xp(skill_id)
		var row: HBoxContainer = entry["row"]
		row.visible = xp > 0.0
		if not row.visible:
			continue
		(entry["bar"] as ProgressBar).value = skill.progress_to_next(xp)
		(entry["level"] as Label).text = "lv %d" % skill.level_for_xp(xp)

	_relations_label.text = _describe_relations()

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


## The three people who matter most to this resident, good or bad. Seeing
## "Anna — close friend (81)" is what makes a household read as a family rather
## than as a group of pathfinding agents.
func _describe_relations() -> String:
	var world := get_tree().get_first_node_in_group(&"world")
	if world == null:
		return ""
	var book := world.get_node_or_null("Relationships") as RelationshipRegistry
	var people := world.get_node_or_null("Citizens") as CitizenRegistry
	if book == null or people == null:
		return ""
	var relations := book.relations_of(_citizen.id)
	if relations.is_empty():
		return "Knows nobody yet"
	var parts: Array[String] = []
	for i in mini(relations.size(), 3):
		var entry: Dictionary = relations[i]
		var other: Citizen = people.citizens.get(int(entry["other"]))
		if other == null:
			continue
		parts.append("%s — %s (%d)" % [
			other.citizen_name.split(" ")[0], book.describe(float(entry["value"])), roundi(float(entry["value"]))])
	return "  •  ".join(parts)


static func _colour_for(value: float) -> Color:
	if value <= GameConstants.NEED_URGENT_THRESHOLD * 0.5:
		return Color(1.0, 0.42, 0.38)
	if value <= GameConstants.NEED_URGENT_THRESHOLD:
		return Color(1.0, 0.75, 0.35)
	return Color(0.55, 0.85, 0.55)
