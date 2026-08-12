class_name BuildingData
extends GameData

## Template for a building lot (design doc §21). In the MVP the player builds a
## house wall by wall, so this describes the *plot* and its role in the city;
## prefab buildings (shop, school, hospital) reuse the same template plus a
## saved room layout.

@export var building_type: GameEnums.BuildingType = GameEnums.BuildingType.RESIDENTIAL

## Plot footprint in cells.
@export var size: Vector2i = Vector2i(8, 8)

@export var price: int = 1000
@export var upkeep_per_day: int = 0

## Residential capacity. 0 for non-residential.
@export var max_residents: int = 4

## Room types this building is expected to contain; the build UI uses it to
## suggest a starting layout.
@export var suggested_room_types: Array[GameEnums.RoomType] = []

## Optional prefab layout: a saved room/wall/furniture blueprint applied when
## the building is placed. Null means the player starts from an empty plot.
@export var blueprint_path: String = ""

## Jobs this building offers when it is not residential.
@export var provides_job_ids: Array[StringName] = []
