class_name StoryPanel
extends UiPanel

## Дневник экспедиции: текущая задача, пройденные главы и финал.
##
## Панель открывается тапом по строке задачи в HUD и сама всплывает в двух
## случаях: когда начинается новая глава и когда игра пройдена.

var story: StorySystem = null

var _current_box: VBoxContainer = null
var _log_box: VBoxContainer = null


func setup(story_system: StorySystem) -> void:
	story = story_system


func _ready() -> void:
	super()
	Events.story_advanced.connect(_on_story_advanced)
	Events.game_won.connect(_on_game_won)


func _build_content(container: VBoxContainer) -> void:
	set_title("Экспедиция")
	var scroll: ScrollContainer = UiWidgets.scroll_list()
	container.add_child(scroll)
	var list: VBoxContainer = UiWidgets.scroll_list_content(scroll)

	_current_box = VBoxContainer.new()
	_current_box.add_theme_constant_override("separation", UiTheme.PAD_S)
	list.add_child(_current_box)

	list.add_child(UiWidgets.separator())

	_log_box = VBoxContainer.new()
	_log_box.add_theme_constant_override("separation", UiTheme.PAD_S)
	list.add_child(_log_box)


func _on_open() -> void:
	refresh()


func refresh() -> void:
	if story == null or _current_box == null:
		return
	UiWidgets.clear_children(_current_box)
	UiWidgets.clear_children(_log_box)

	if story.is_finished():
		_current_box.add_child(UiWidgets.label(Story.ENDING_TITLE, UiTheme.FONT_LARGE, Palette.OK))
		_current_box.add_child(_paragraph(Story.ENDING_TEXT))
	else:
		var chapter: Dictionary = story.chapter()
		_current_box.add_child(UiWidgets.label(String(chapter["title"]), UiTheme.FONT_LARGE))
		_current_box.add_child(_paragraph(String(chapter["text"])))
		_current_box.add_child(UiWidgets.label(
			"Задача: %s" % story.hint(), UiTheme.FONT_NORMAL, Palette.ACCENT
		))
		var progress: String = story.progress_text()
		if not progress.is_empty():
			_current_box.add_child(UiWidgets.label(progress, UiTheme.FONT_SMALL, Palette.UI_TEXT_DIM))

	# Журнал пройденного: короткая память о том, как далеко зашла экспедиция.
	if story.current > 0:
		_log_box.add_child(UiWidgets.label("Пройдено", UiTheme.FONT_SMALL, Palette.UI_TEXT_DIM))
	for i: int in story.current:
		var done: Dictionary = Story.chapter_at(i)
		_log_box.add_child(UiWidgets.label(
			"✓ %s" % String(done["title"]), UiTheme.FONT_SMALL, Palette.OK
		))


static func _paragraph(text: String) -> Label:
	var label: Label = UiWidgets.label(text, UiTheme.FONT_SMALL, Palette.UI_TEXT)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _on_story_advanced(_finished_id: StringName, next_id: StringName) -> void:
	# Новая глава — повод показать текст: это и сюжет, и подсказка, что делать.
	if next_id != &"":
		open()
	refresh()


func _on_game_won() -> void:
	open()
	refresh()
