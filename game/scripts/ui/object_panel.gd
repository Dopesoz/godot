extends PanelContainer

## "What is this, and what is it for?" — the panel that opens when the player
## taps an object with no tool in hand.
##
## Everything it shows comes from the object's own data: the description, what
## can be done with it, what each of those does to a need, how long it takes and
## which skill it trains. That is deliberate — the alternative is a written
## description per object that drifts out of step with the numbers the
## simulation actually uses. Here, if the sofa's comfort changes, this panel
## changes with it.

const NEED_NAMES := {
	GameEnums.NeedType.HUNGER: "hunger",
	GameEnums.NeedType.ENERGY: "energy",
	GameEnums.NeedType.HYGIENE: "hygiene",
	GameEnums.NeedType.COMFORT: "comfort",
	GameEnums.NeedType.ENTERTAINMENT: "fun",
	GameEnums.NeedType.SOCIAL: "company",
	GameEnums.NeedType.WORK: "work",
}

var _layout: VBoxContainer
var _item: Furniture


func _ready() -> void:
	visible = false
	UiTheme.apply(self)
	set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	var margins := Platform.safe_area_margins()
	offset_left = 16.0 + float(margins.x)
	offset_bottom = -190.0 * Platform.ui_scale() - float(margins.w)
	offset_top = offset_bottom - 40.0

	_layout = VBoxContainer.new()
	_layout.add_theme_constant_override(&"separation", 6)
	add_child(_layout)
	EventBus.selection_changed.connect(_on_selection_changed)
	EventBus.furniture_removed.connect(_on_furniture_removed)


func _on_selection_changed(selected: Variant) -> void:
	_item = selected as Furniture
	visible = _item != null
	if visible:
		_refresh()


func _on_furniture_removed(furniture_id: int) -> void:
	if _item != null and _item.id == furniture_id:
		EventBus.selection_changed.emit(null)


func _refresh() -> void:
	for child in _layout.get_children():
		child.queue_free()
	var template := _item.data()
	if template == null:
		return

	_title(tr(template.display_name))
	if template.description != "":
		_line(tr(template.description), Color(0.72, 0.77, 0.84), true)

	var facts := PackedStringArray()
	facts.append("$%d" % template.price)
	if template.upkeep_per_day > 0:
		facts.append(tr("$%d/day upkeep") % template.upkeep_per_day)
	if template.comfort > 0.0:
		facts.append(tr("comfort %d") % roundi(template.comfort))
	if template.entertainment > 0.0:
		facts.append(tr("fun %d") % roundi(template.entertainment))
	facts.append("%dx%d" % [template.size.x, template.size.y])
	_line("  •  ".join(facts), Color(0.62, 0.68, 0.76))

	if template.interactions.is_empty():
		_line(tr("Nothing to do with it — it is here to look at."), Color(0.62, 0.68, 0.76), true)
	for interaction: InteractionData in template.interactions:
		_interaction_row(interaction)

	if not _item.users.is_empty():
		_line(tr("In use right now"), Color(1.0, 0.87, 0.55))


## One line per thing you can do with the object: what it gives, what it costs,
## how long it takes, and what it teaches.
func _interaction_row(interaction: InteractionData) -> void:
	var gains := PackedStringArray()
	var costs := PackedStringArray()
	for need: int in interaction.need_effects:
		var amount := float(interaction.need_effects[need])
		var name: String = tr(NEED_NAMES.get(need, "need"))
		if amount >= 0.0:
			gains.append("+%d %s" % [roundi(amount), name])
		else:
			costs.append("%d %s" % [roundi(amount), name])
	var parts := PackedStringArray()
	if not gains.is_empty():
		parts.append(", ".join(gains))
	if not costs.is_empty():
		parts.append(", ".join(costs))
	parts.append(tr("%d min") % roundi(interaction.duration_minutes))
	if interaction.skill_id != &"":
		var skill := Database.get_skill(interaction.skill_id)
		parts.append(tr("trains %s") % tr(skill.display_name if skill != null else String(interaction.skill_id)))
	_line("%s — %s" % [tr(interaction.display_name), "  ·  ".join(parts)], Color(0.85, 0.90, 0.96), true)


func _title(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", roundi(19 * Platform.ui_scale()))
	_layout.add_child(label)


func _line(text: String, color: Color, wrap: bool = false) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_font_size_override(&"font_size", roundi(13 * Platform.ui_scale()))
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = 340.0 * Platform.ui_scale()
	_layout.add_child(label)
