class_name RoomTypeData
extends GameData

## Describes one room purpose (design doc §9). Kept as data rather than a plain
## enum entry so that the build UI, the auto-detection pass and the AI all read
## the same source: which furniture belongs here, and what the room is good for.

@export var room_type: GameEnums.RoomType = GameEnums.RoomType.UNDEFINED

## Furniture ids that mark a room as this type. Used later by automatic room
## classification; for now the player picks the type manually.
@export var signature_furniture_ids: Array[StringName] = []

## Minimum floor area in cells for the type to be assignable.
@export var min_area: int = 1

## Needs a citizen expects to satisfy in this room. Lets the AI narrow its
## search to one room instead of scanning every object in the city.
@export var satisfies_needs: Array[GameEnums.NeedType] = []

## Can citizens who do not live here walk in? False for bedrooms and bathrooms
## once relationships exist.
@export var is_private: bool = false

@export var default_floor_color: Color = Color(0.55, 0.45, 0.35)
