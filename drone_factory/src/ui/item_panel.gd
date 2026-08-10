class_name ItemPanel
extends UiPanel

## Справка по предмету: что это, где берут, куда девают, сколько осталось.
##
## Открывается тапом по любой иконке ресурса — в верхней панели, в складе,
## в списке рецептов. До неё единственным способом понять, зачем нужен, скажем,
## медный провод, был перебор рецептов вручную.
##
## Панель принципиально только читает: никаких кнопок, кроме закрытия. Это
## справочник, а не пульт, и открывать его должно быть безопасно в любой момент.

var world: GameWorld = null

var _item_id: StringName = &""
var _icon: TextureRect = null
var _summary: Label = null
var _sections: VBoxContainer = null


func setup(game_world: GameWorld) -> void:
	world = game_world


func _build_content(container: VBoxContainer) -> void:
	set_title("Предмет")

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", UiTheme.PAD_M)
	container.add_child(header)

	_icon = TextureRect.new()
	_icon.name = "Icon"
	_icon.custom_minimum_size = Vector2(48, 48)
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(_icon)

	_summary = UiWidgets.paragraph("", UiTheme.FONT_SMALL, Palette.UI_TEXT_DIM)
	_summary.name = "Summary"
	_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_summary)

	container.add_child(UiWidgets.separator())

	_sections = VBoxContainer.new()
	_sections.name = "Sections"
	_sections.add_theme_constant_override("separation", UiTheme.PAD_S)
	container.add_child(_sections)


## Открывает справку по конкретному предмету.
func show_item(item_id: StringName) -> void:
	if not Items.exists(item_id):
		return
	_item_id = item_id
	open()
	refresh()


func item_id() -> StringName:
	return _item_id


func refresh() -> void:
	if _item_id == &"" or _sections == null:
		return
	set_title(Items.display_name(_item_id))
	_icon.texture = Art.icon(_item_id)

	var source: String = Items.source_of(_item_id)
	var stock: int = 0 if world == null or world.buildings == null else \
		ResourcePool.new(world.buildings).count(_item_id)
	var parts: PackedStringArray = PackedStringArray()
	parts.append("На складах: %s" % UiWidgets.short_number(stock))
	if not source.is_empty():
		parts.append("Где делают: %s" % source)
	_summary.text = "\n".join(parts)

	UiWidgets.clear_children(_sections)
	_add_reserves()
	_add_recipe_section("Из чего делают", Recipes.producing(_item_id))
	_add_list("Идёт в производство", _recipe_names(ItemInfo.used_in(_item_id)))
	_add_list("Питает здания", _building_names(ItemInfo.consumed_by(_item_id)))
	_add_list("Идёт на постройку", _building_names(ItemInfo.builds(_item_id)))
	_add_list("Тратится на исследования", _tech_names(ItemInfo.researches(_item_id)))
	if ItemInfo.tradable(_item_id):
		var rate: Vector2i = ResearchSystem.TRADE_RATES[_item_id]
		_add_list("Обмен на науку", PackedStringArray([
			"%d штук -> %d колб, кнопка в панели исследований" % [rate.x, rate.y],
		]))


## Запасы в земле — то, ради чего справку и открывают у руды.
func _add_reserves() -> void:
	if world == null:
		return
	var left: int = ItemInfo.reserves(world.grid, _item_id)
	if left < 0:
		return
	_sections.add_child(UiWidgets.label(
		"Осталось в земле: %s" % UiWidgets.short_number(left),
		UiTheme.FONT_NORMAL,
		Palette.BAD if left < 5000 else Palette.OK
	))


func _add_recipe_section(caption: String, recipe_id: StringName) -> void:
	if recipe_id == &"":
		return
	var parts: PackedStringArray = PackedStringArray()
	for input_id: StringName in Recipes.inputs(recipe_id):
		parts.append("%s %d" % [
			Items.display_name(input_id), int(Recipes.inputs(recipe_id)[input_id]),
		])
	if parts.is_empty():
		return
	_add_list(caption, PackedStringArray([", ".join(parts)]))


func _add_list(caption: String, values: PackedStringArray) -> void:
	if values.is_empty():
		return
	_sections.add_child(UiWidgets.label(caption, UiTheme.FONT_SMALL, Palette.UI_TEXT_DIM))
	_sections.add_child(UiWidgets.paragraph(", ".join(values), UiTheme.FONT_SMALL))


static func _recipe_names(ids: Array[StringName]) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for id: StringName in ids:
		result.append(Recipes.display_name(id))
	return result


static func _building_names(ids: Array[StringName]) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for id: StringName in ids:
		result.append(BuildingDefs.display_name(id))
	return result


static func _tech_names(ids: Array[StringName]) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for id: StringName in ids:
		result.append(Technologies.display_name(id))
	return result
