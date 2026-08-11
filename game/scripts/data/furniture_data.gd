class_name FurnitureData
extends GameData

## Template for a placeable object: bed, sofa, table, fridge, stove, shower…
## (design doc §10). Adding a new object to the game means adding one .tres
## file — no code changes anywhere.

enum Category {
	SEATING,
	SLEEPING,
	SURFACE,
	APPLIANCE,
	PLUMBING,
	STORAGE,
	ELECTRONICS,
	DECOR,
	LIGHTING,
}

@export var category: Category = Category.DECOR

## Purchase price and the daily upkeep it adds to the household bill.
@export var price: int = 100
@export var upkeep_per_day: int = 0

## Footprint in cells before rotation. Vector2i(1, 1) is a chair, (2, 1) a bed.
@export var size: Vector2i = Vector2i.ONE

## Passive room quality contributions, used when scoring a room's comfort.
@export_range(0.0, 100.0) var comfort: float = 0.0
@export_range(0.0, 100.0) var entertainment: float = 0.0

## Does it block citizen movement through its cells?
@export var blocks_movement: bool = true

## Must it be placed against a wall (wardrobe) or is it free-standing (table)?
@export var requires_wall: bool = false

## Everything a citizen can do with it. Empty means purely decorative.
@export var interactions: Array[InteractionData] = []

## Room types where this object is allowed / suggested by the build UI.
## Empty means "anywhere".
@export var allowed_room_types: Array[GameEnums.RoomType] = []


## Footprint after rotating by `rotation_steps` * 90 degrees.
func rotated_size(rotation_steps: int) -> Vector2i:
	if rotation_steps % 2 == 0:
		return size
	return Vector2i(size.y, size.x)


## First interaction that raises `need`, or null. The AI uses this to answer
## "can this object make me less hungry?" without knowing what a fridge is.
func find_interaction_for(need: GameEnums.NeedType) -> InteractionData:
	for interaction in interactions:
		if interaction != null and float(interaction.need_effects.get(need, 0.0)) > 0.0:
			return interaction
	return null
