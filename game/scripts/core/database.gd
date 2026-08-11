extends Node

## Autoload: Database
##
## Loads every GameData resource under res://resources/ once at startup and
## indexes it by id. Nothing else in the project is allowed to call `load()` on
## content — systems ask the Database, which keeps content lookup, hot-reload
## and modding in one place.
##
## This is the backbone of the data-driven design in §5 of the design doc:
## adding a hundred furniture items means adding a hundred .tres files.

const RESOURCE_ROOT := "res://resources"

## StringName id -> GameData, one dictionary per content type.
var furniture: Dictionary = {}
var floors: Dictionary = {}
var citizens: Dictionary = {}
var jobs: Dictionary = {}
var buildings: Dictionary = {}
var room_types: Dictionary = {}
var schedules: Dictionary = {}
var skills: Dictionary = {}

var _loaded: bool = false
var _errors: PackedStringArray = PackedStringArray()


func _ready() -> void:
	reload()


func reload() -> void:
	furniture.clear()
	floors.clear()
	citizens.clear()
	jobs.clear()
	buildings.clear()
	room_types.clear()
	schedules.clear()
	skills.clear()
	_errors.clear()
	_scan_dir(RESOURCE_ROOT)
	_loaded = true
	EventBus.notify("Database: %d furniture, %d floors, %d citizens, %d schedules, %d jobs, %d buildings, %d room types"
			% [furniture.size(), floors.size(), citizens.size(), schedules.size(), jobs.size(), buildings.size(), room_types.size()])
	for error in _errors:
		push_warning("Database: " + error)


func _scan_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		_errors.append("cannot open %s" % path)
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var full := path.path_join(entry)
		if dir.current_is_dir():
			_scan_dir(full)
		else:
			# Exported builds list resources with a .remap suffix; loading the
			# stripped path resolves to the real file.
			if full.ends_with(".remap"):
				full = full.trim_suffix(".remap")
			if full.get_extension() == "tres" or full.get_extension() == "res":
				_register(full)
		entry = dir.get_next()
	dir.list_dir_end()


func _register(path: String) -> void:
	var res: Resource = ResourceLoader.load(path)
	if res == null:
		_errors.append("failed to load %s" % path)
		return
	if not (res is GameData):
		return
	var data: GameData = res
	if not data.is_valid():
		_errors.append("%s has an empty id" % path)
		return
	var bucket := _bucket_for(data)
	if bucket == null:
		_errors.append("%s has an unknown GameData subtype" % path)
		return
	if bucket.has(data.id):
		_errors.append("duplicate id '%s' in %s" % [data.id, path])
		return
	bucket[data.id] = data


func _bucket_for(data: GameData) -> Dictionary:
	if data is FurnitureData:
		return furniture
	if data is FloorData:
		return floors
	if data is CitizenData:
		return citizens
	if data is JobData:
		return jobs
	if data is BuildingData:
		return buildings
	if data is RoomTypeData:
		return room_types
	if data is ScheduleData:
		return schedules
	if data is SkillData:
		return skills
	return {}


# --- Lookup -----------------------------------------------------------------
# Each getter returns null on a miss and logs it, so a typo in a save file or a
# .tres surfaces immediately instead of crashing three systems later.

func get_furniture(id: StringName) -> FurnitureData:
	return _lookup(furniture, id, "furniture") as FurnitureData


func get_floor(id: StringName) -> FloorData:
	return _lookup(floors, id, "floor") as FloorData


## Floor materials in a stable order, for the build menu.
func all_floors() -> Array[FloorData]:
	var result: Array[FloorData] = []
	for id: StringName in _sorted_ids(floors):
		result.append(floors[id])
	return result


func _sorted_ids(bucket: Dictionary) -> Array:
	var ids := bucket.keys()
	ids.sort()
	return ids


func get_citizen(id: StringName) -> CitizenData:
	return _lookup(citizens, id, "citizen") as CitizenData


func get_job(id: StringName) -> JobData:
	return _lookup(jobs, id, "job") as JobData


func get_building(id: StringName) -> BuildingData:
	return _lookup(buildings, id, "building") as BuildingData


func get_schedule(id: StringName) -> ScheduleData:
	return _lookup(schedules, id, "schedule") as ScheduleData


func get_skill(id: StringName) -> SkillData:
	return _lookup(skills, id, "skill") as SkillData


## Skills in a stable order, for the inspector.
func all_skills() -> Array[SkillData]:
	var result: Array[SkillData] = []
	for id: StringName in _sorted_ids(skills):
		result.append(skills[id])
	return result


func get_room_type(room_type: GameEnums.RoomType) -> RoomTypeData:
	for data: RoomTypeData in room_types.values():
		if data.room_type == room_type:
			return data
	return null


func _lookup(bucket: Dictionary, id: StringName, kind: String) -> Variant:
	if bucket.has(id):
		return bucket[id]
	push_warning("Database: unknown %s id '%s'" % [kind, id])
	return null


## Every furniture template in a category, for the build menu.
func furniture_in_category(category: FurnitureData.Category) -> Array[FurnitureData]:
	var result: Array[FurnitureData] = []
	for data: FurnitureData in furniture.values():
		if data.category == category:
			result.append(data)
	return result


func is_loaded() -> bool:
	return _loaded


func get_errors() -> PackedStringArray:
	return _errors
