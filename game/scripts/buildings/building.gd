class_name Building
extends RefCounted

## A plot on the map: this house, this shop. Everything inside it — walls,
## rooms, furniture, residents — belongs to it by *position*, not by a list.
##
## That is the important decision. A building could own an array of rooms and an
## array of objects, and then every wall the player moves would have to be
## reconciled with those arrays. Instead the plot claims a rectangle of cells,
## each cell records which building it belongs to, and everything standing on a
## cell inherits that. Nothing to keep in sync, and "which house is this bed in?"
## is a single lookup.

var id: int = -1
var data_id: StringName = &""
## Player-facing name: "Meyer House", "Corner Shop".
## The English template name ("Small House"), kept as written so it can be
## translated at the moment it is shown, plus the number that tells two of them
## apart. Storing the finished string would freeze it into whatever language the
## town was founded in.
var display_name: String = ""

## Set when a household moves in: a house is "The Adlers" rather than
## "Small House 3". A name a player would recognise wins over a generated one,
## and a surname needs no translation.
var custom_name: String = ""
## Top-left cell and size in cells.
var origin: Vector2i = Vector2i.ZERO
var size: Vector2i = Vector2i.ONE
var floor_index: int = 0

## Household living here, -1 for none or for a non-residential plot.
var household_id: int = -1

var _data: BuildingData


func data() -> BuildingData:
	if _data == null and data_id != &"":
		_data = Database.get_building(data_id)
	return _data


func building_type() -> int:
	var template := data()
	return template.building_type if template != null else GameEnums.BuildingType.RESIDENTIAL


func is_residential() -> bool:
	return building_type() == GameEnums.BuildingType.RESIDENTIAL


func rect() -> Rect2i:
	return Rect2i(origin, size)


func contains(cell: Vector2i) -> bool:
	return rect().has_point(cell)


func cells() -> Array[Vector2i]:
	return IsoUtils.cells_in_rect(origin, origin + size - Vector2i.ONE)


func centre() -> Vector2:
	return Vector2(origin) + Vector2(size - Vector2i.ONE) * 0.5


func max_residents() -> int:
	var template := data()
	return template.max_residents if template != null else 0


## What to show the player: the template's name in their language, numbered.
func label() -> String:
	if custom_name != "":
		return custom_name
	var data := Database.get_building(data_id)
	var base := Loc.t(data.display_name) if data != null else Loc.t(display_name)
	return "%s %d" % [base, id]


func save_data() -> Dictionary:
	return {
		"id": id,
		"data_id": String(data_id),
		"name": display_name,
		"custom_name": custom_name,
		"x": origin.x,
		"y": origin.y,
		"w": size.x,
		"h": size.y,
		"floor": floor_index,
		"household": household_id,
	}


static func from_save(entry: Dictionary) -> Building:
	var building := Building.new()
	building.id = int(entry.get("id", -1))
	building.data_id = StringName(entry.get("data_id", ""))
	building.display_name = String(entry.get("name", ""))
	building.custom_name = String(entry.get("custom_name", ""))
	building.origin = Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
	building.size = Vector2i(int(entry.get("w", 1)), int(entry.get("h", 1)))
	building.floor_index = int(entry.get("floor", 0))
	building.household_id = int(entry.get("household", -1))
	return building
