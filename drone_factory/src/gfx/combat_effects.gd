class_name CombatEffects
extends Node2D

## Живая часть боя: поворотные стволы турелей и вспышки выстрелов.
##
## Отдельный слой, а не часть отрисовки зданий, по той же причине, что и шкалы
## выработки: слой зданий перерисовывается только при изменениях и обходит все
## видимые постройки, а ствол ведёт цель непрерывно. Здесь перерисовываются
## только турели в кадре, и их всегда единицы.

## Дальше этого (в клетках по ширине экрана) стволы не рисуются: на общем
## плане турель занимает несколько пикселей, и деталь всё равно не видна.
const MAX_VISIBLE_CELLS: int = 60

var registry: BuildingRegistry = null

var _visible_cells := Rect2i(0, 0, 0, 0)


func _ready() -> void:
	z_index = 3


func setup(building_registry: BuildingRegistry) -> void:
	registry = building_registry


func set_view(visible_cells: Rect2i) -> void:
	_visible_cells = visible_cells


func _process(_delta: float) -> void:
	if registry != null:
		queue_redraw()


func _draw() -> void:
	if registry == null or _visible_cells.size.x > MAX_VISIBLE_CELLS:
		return
	var atlas: Texture2D = Art.object_texture
	var region: Rect2i = Art.region(ObjectArt.TURRET_BARREL)
	if region.size == Vector2i.ZERO:
		return

	for building: Building in registry.of_kind(BuildingDefs.Kind.TURRET):
		if not _visible_cells.intersects(building.rect()):
			continue
		_draw_turret(atlas, region, building as Turret)


func _draw_turret(atlas: Texture2D, region: Rect2i, turret: Turret) -> void:
	var centre: Vector2 = turret.center()
	# Спрайт ствола нарисован так, что ось поворота — его центр, поэтому
	# рисуем со сдвигом на половину и крутим вокруг этой точки.
	var half := Vector2(region.size) * 0.5
	draw_set_transform(centre, turret.aim_angle, Vector2.ONE)
	draw_texture_rect_region(atlas, Rect2(-half, Vector2(region.size)), Rect2(region))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if turret.flash_left <= 0.0:
		return
	# Вспышка у среза: короткая, но яркая — по ней видно, какая именно турель
	# работает, не вглядываясь в стволы.
	var muzzle: Vector2 = centre + Vector2(half.x - 2.0, 0.0).rotated(turret.aim_angle)
	var fade: float = clampf(turret.flash_left / Turret.FLASH_SECONDS, 0.0, 1.0)
	draw_circle(muzzle, 5.0 * fade, Color(Palette.WARN, fade))
	draw_circle(muzzle, 2.5 * fade, Color(1.0, 1.0, 0.85, fade))
