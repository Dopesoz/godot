class_name AchievementsPanel
extends UiPanel

## Список достижений: что уже сделано и сколько осталось до следующего.
##
## Прогресс показывается цифрами («43 / 100»), а не только галочкой: половина
## смысла достижений — видеть, что цель близко.

var achievements: AchievementSystem = null

var _summary: Label = null
var _list: VBoxContainer = null


func setup(system: AchievementSystem) -> void:
	achievements = system


func _ready() -> void:
	super()
	Events.achievement_unlocked.connect(_on_unlocked)


func _build_content(container: VBoxContainer) -> void:
	set_title("Достижения")
	_summary = UiWidgets.label("", UiTheme.FONT_SMALL, Palette.UI_TEXT_DIM)
	container.add_child(_summary)

	_list = VBoxContainer.new()
	_list.name = "List"
	_list.add_theme_constant_override("separation", UiTheme.PAD_S)
	container.add_child(_list)


func _on_open() -> void:
	refresh()


func refresh() -> void:
	if _list == null or achievements == null:
		return
	_summary.text = "Открыто %d из %d" % [
		achievements.unlocked_count(), Achievements.all_ids().size(),
	]

	UiWidgets.clear_children(_list)
	# Сначала открытые: свежая награда должна быть на виду.
	for want_unlocked: bool in [true, false]:
		for id: StringName in Achievements.all_ids():
			if achievements.is_unlocked(id) == want_unlocked:
				_list.add_child(_build_row(id))


func _build_row(id: StringName) -> Control:
	var done: bool = achievements.is_unlocked(id)
	var panel := PanelContainer.new()
	panel.name = String(id)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	panel.add_child(box)

	box.add_child(UiWidgets.label(
		("✓ " if done else "") + Achievements.display_name(id),
		UiTheme.FONT_NORMAL,
		Palette.OK if done else Palette.UI_TEXT
	))
	var detail: String = Achievements.description(id)
	if not done:
		detail += " · " + achievements.progress_text(id)
	var detail_label: Label = UiWidgets.label(detail, UiTheme.FONT_SMALL, Palette.UI_TEXT_DIM)
	detail_label.name = "Detail"
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(detail_label)
	return panel


func _on_unlocked(_id: StringName) -> void:
	if is_open():
		refresh()
