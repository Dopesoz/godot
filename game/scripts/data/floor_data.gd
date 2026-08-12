class_name FloorData
extends GameData

## A flooring material (design doc §8, step 7). Separate from FurnitureData
## because a floor is not an object standing in a cell — it is a property of the
## cell itself, it costs per tile, and it never blocks movement.

@export var price_per_tile: int = 10

## Roads are floor materials, not a separate system. That means the player
## paints a street with the same tool they use to lay a carpet, cars know where
## they may drive by asking the ground what it is made of, and nothing else in
## the game had to learn a new concept.
@export var is_road: bool = false

## Small passive contribution to the comfort of any room built on it.
@export_range(0.0, 20.0) var comfort: float = 0.0

## Room types this material suits, used to sort the build menu. Empty = any.
@export var suggested_room_types: Array[GameEnums.RoomType] = []
