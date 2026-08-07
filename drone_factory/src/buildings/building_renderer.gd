class_name BuildingRenderer
extends Node2D

## Отрисовка всех зданий одним узлом.
##
## Здания не являются узлами сцены, поэтому рисуются здесь пакетом: один
## canvas item, одна текстура-атлас, отсечение по видимой области. Перерисовка
## запускается только по событиям и не чаще частоты логического тика —
## статичная фабрика не стоит ничего.

## Прозрачность призрака постройки.
const GHOST_ALPHA: float = 0.65
const GHOST_BAD_TINT := Color(1.0, 0.45, 0.4, GHOST_ALPHA)
const GHOST_OK_TINT := Color(1.0, 1.0, 1.0, GHOST_ALPHA)

var registry: BuildingRegistry = null

## Что показывать под пальцем в режиме строительства.
var ghost_def_id: StringName = &""
var ghost_origin: Vector2i = Vector2i.ZERO
var ghost_valid: bool = false

var selected_id: int = 0

var _visible_cells := Rect2i(0, 0, 0, 0)
var _dirty: bool = true


func _ready() -> void:
	z_index = 2
	Events.building_placed.connect(_on_building_changed)
	Events.building_removed.connect(_on_building_changed)
	Events.building_state_changed.connect(_on_building_changed)
	Events.selection_changed.connect(_on_selection_changed)


func setup(building_registry: BuildingRegistry) -> void:
	registry = building_registry
	mark_dirty()


func set_view(visible_cells: Rect2i) -> void:
	if visible_cells == _visible_cells:
		return
	_visible_cells = visible_cells
	mark_dirty()


func set_ghost(def_id: StringName, origin: Vector2i, valid: bool) -> void:
	if def_id == ghost_def_id and origin == ghost_origin and valid == ghost_valid:
		return
	ghost_def_id = def_id
	ghost_origin = origin
	ghost_valid = valid
	mark_dirty()


func clear_ghost() -> void:
	set_ghost(&"", Vector2i.ZERO, false)


func mark_dirty() -> void:
	_dirty = true


func _process(_delta: float) -> void:
	if _dirty:
		_dirty = false
		queue_redraw()


func _draw() -> void:
	if registry == null:
		return
	var atlas: Texture2D = Art.object_texture
	for building: Building in registry.in_rect(_visible_cells):
		_draw_building(atlas, building)
	if selected_id != 0:
		_draw_selection(atlas)
	if ghost_def_id != &"":
		_draw_ghost(atlas)


func _draw_building(atlas: Texture2D, building: Building) -> void:
	var region: Rect2i = Art.region(building.def_id)
	if region.size == Vector2i.ZERO:
		return
	var position: Vector2 = Grid.cell_to_world(building.origin)
	draw_texture_rect_region(atlas, Rect2(position, Vector2(region.size)), Rect2(region))

	var badge: StringName = _badge_for(building)
	if badge != &"":
		var badge_region: Rect2i = Art.region(badge)
		# Значок в правом верхнем углу здания, слегка выступая наружу.
		var badge_position: Vector2 = position + Vector2(
			float(building.size.x * Constants.TILE_SIZE - badge_region.size.x + 2), -2.0
		)
		draw_texture_rect_region(
			atlas, Rect2(badge_position, Vector2(badge_region.size)), Rect2(badge_region)
		)


func _draw_selection(atlas: Texture2D) -> void:
	var building: Building = registry.get_building(selected_id)
	if building == null:
		return
	var region: Rect2i = Art.region(ObjectArt.SELECTION)
	var rect: Rect2i = building.rect()
	# Уголки рисуются по углам занятой площади, а не по каждой клетке.
	for corner: Vector2i in [
		rect.position,
		rect.position + Vector2i(rect.size.x - 1, 0),
		rect.position + Vector2i(0, rect.size.y - 1),
		rect.position + rect.size - Vector2i.ONE,
	]:
		draw_texture_rect_region(
			atlas,
			Rect2(Grid.cell_to_world(corner), Vector2(region.size)),
			Rect2(region)
		)


func _draw_ghost(atlas: Texture2D) -> void:
	var region: Rect2i = Art.region(ghost_def_id)
	if region.size == Vector2i.ZERO:
		return
	draw_texture_rect_region(
		atlas,
		Rect2(Grid.cell_to_world(ghost_origin), Vector2(region.size)),
		Rect2(region),
		GHOST_OK_TINT if ghost_valid else GHOST_BAD_TINT
	)
	# Подсветка занимаемой площади: на маленьком экране важно видеть габарит.
	var size: Vector2i = BuildingDefs.size_of(ghost_def_id)
	var area := Rect2(
		Grid.cell_to_world(ghost_origin),
		Vector2(size * Constants.TILE_SIZE)
	)
	draw_rect(area, Color(GHOST_OK_TINT if ghost_valid else GHOST_BAD_TINT, 0.18), true)
	draw_rect(area, Color(GHOST_OK_TINT if ghost_valid else GHOST_BAD_TINT, 0.9), false, 1.0)


static func _badge_for(building: Building) -> StringName:
	match building.status:
		Building.Status.NO_POWER:
			return ObjectArt.BADGE_NO_POWER
		Building.Status.NO_INPUT:
			return ObjectArt.BADGE_NO_INPUT
		Building.Status.OUTPUT_FULL:
			return ObjectArt.BADGE_FULL
		Building.Status.NO_ORE:
			return ObjectArt.BADGE_NO_ORE
		_:
			return &""


func _on_building_changed(_building_id: int) -> void:
	mark_dirty()


func _on_selection_changed(building_id: int) -> void:
	selected_id = maxi(building_id, 0)
	mark_dirty()
