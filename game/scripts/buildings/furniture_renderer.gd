extends Node2D

## Draws placed furniture as simple raised blocks (placeholders per §28).
##
## Sorted back to front by footprint depth so a sofa in front covers the table
## behind it. Furniture is drawn before walls: a wall on the south side of a room
## should hide what stands behind it, and that is the common case. When citizens
## arrive in Phase 4 this layer and the wall layer merge into one depth-sorted
## pass, which is the only way to get it right in every case.

const HEIGHT := 20.0
const TOP_LIGHTEN := 0.18
const SIDE_DARKEN := 0.28
const OUTLINE := Color(0.12, 0.12, 0.14, 0.55)
const SHADOW := Color(0.0, 0.0, 0.0, 0.18)

var _items: Array = []


func _ready() -> void:
	EventBus.furniture_placed.connect(_on_changed)
	EventBus.furniture_removed.connect(_on_changed)


func _on_changed(_arg: Variant) -> void:
	_refresh()


func _refresh() -> void:
	var registry := get_parent().get_node_or_null("Furniture") as FurnitureRegistry
	if registry == null:
		return
	_items = registry.items.values()
	_items.sort_custom(func(a: Furniture, b: Furniture) -> bool:
		return a.center().x + a.center().y < b.center().x + b.center().y)
	queue_redraw()


func _draw() -> void:
	for item: Furniture in _items:
		_draw_item(item)


func _draw_item(item: Furniture) -> void:
	var template := item.data()
	if template == null:
		return
	var base := template.placeholder_color
	var height := HEIGHT if template.blocks_movement else HEIGHT * 0.55
	var lift := Vector2(0.0, -height)

	for cell in item.cells():
		var polygon := IsoUtils.cell_polygon(cell, item.floor_index)
		draw_colored_polygon(polygon, SHADOW)

		# Two visible side faces, then the top: enough to read as a solid box.
		var top := PackedVector2Array()
		for point in polygon:
			top.append(point + lift)
		draw_colored_polygon(PackedVector2Array([polygon[1], polygon[2], top[2], top[1]]),
				base.darkened(SIDE_DARKEN))
		draw_colored_polygon(PackedVector2Array([polygon[2], polygon[3], top[3], top[2]]),
				base.darkened(SIDE_DARKEN * 0.5))
		draw_colored_polygon(top, base.lightened(TOP_LIGHTEN))
		draw_polyline(top + PackedVector2Array([top[0]]), OUTLINE, 1.0)
