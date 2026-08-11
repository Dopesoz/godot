extends Node

## Autoload: SaveManager
##
## Scene-independent persistence (design doc §25). It knows nothing about the
## world, buildings or citizens. Instead, each system registers itself under a
## key and provides two methods:
##
##     func save_data() -> Dictionary
##     func load_data(data: Dictionary) -> void
##
## Saving is then "ask every provider for a dictionary and write JSON"; loading
## is the reverse. Adding a new system to the save file is one `register` call.
##
## This only works because the model layer is plain data. If citizens lived
## inside nodes, this file would have to walk the scene tree and would break
## every time a scene was reorganised.

const PROVIDER_ORDER_HINT := ["clock", "economy", "world", "buildings", "citizens", "families"]

## key -> Object implementing save_data/load_data.
var _providers: Dictionary = {}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(GameConstants.SAVE_DIR)
	# The always-present services register themselves; gameplay systems register
	# when they are created.
	register("clock", GameClock)
	register("economy", Economy)


func register(key: String, provider: Object) -> void:
	if provider == null:
		push_warning("SaveManager: null provider for '%s'" % key)
		return
	if not provider.has_method("save_data") or not provider.has_method("load_data"):
		push_warning("SaveManager: '%s' does not implement save_data/load_data" % key)
		return
	_providers[key] = provider


func unregister(key: String) -> void:
	_providers.erase(key)


func slot_path(slot: String) -> String:
	return GameConstants.SAVE_DIR.path_join(slot + GameConstants.SAVE_EXTENSION)


func has_slot(slot: String) -> bool:
	return FileAccess.file_exists(slot_path(slot))


func list_slots() -> PackedStringArray:
	var slots := PackedStringArray()
	var dir := DirAccess.open(GameConstants.SAVE_DIR)
	if dir == null:
		return slots
	for file in dir.get_files():
		if file.ends_with(GameConstants.SAVE_EXTENSION):
			slots.append(file.trim_suffix(GameConstants.SAVE_EXTENSION))
	return slots


func save_game(slot: String = "slot1") -> bool:
	EventBus.save_started.emit(slot)
	var payload := {
		"version": GameConstants.SAVE_FORMAT_VERSION,
		"saved_at": Time.get_datetime_string_from_system(true),
		"systems": {},
	}
	for key in _sorted_keys():
		var provider: Object = _providers[key]
		payload["systems"][key] = provider.call("save_data")

	var file := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: cannot write %s (%d)" % [slot_path(slot), FileAccess.get_open_error()])
		EventBus.save_finished.emit(slot, false)
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	EventBus.save_finished.emit(slot, true)
	return true


func load_game(slot: String = "slot1") -> bool:
	EventBus.load_started.emit(slot)
	var file := FileAccess.open(slot_path(slot), FileAccess.READ)
	if file == null:
		EventBus.load_finished.emit(slot, false)
		return false
	var text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SaveManager: %s is not valid save JSON" % slot)
		EventBus.load_finished.emit(slot, false)
		return false
	var payload: Dictionary = parsed
	var version := int(payload.get("version", 0))
	if version > GameConstants.SAVE_FORMAT_VERSION:
		push_error("SaveManager: save version %d is newer than this build" % version)
		EventBus.load_finished.emit(slot, false)
		return false
	payload = _migrate(payload, version)

	var systems: Dictionary = payload.get("systems", {})
	for key in _sorted_keys():
		if not systems.has(key):
			continue
		var provider: Object = _providers[key]
		provider.call("load_data", systems[key] as Dictionary)
	EventBus.load_finished.emit(slot, true)
	return true


func delete_slot(slot: String) -> void:
	if has_slot(slot):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(slot_path(slot)))


## Providers are loaded in a fixed order because later systems reference earlier
## ones — citizens need the world and the clock to already be in place.
func _sorted_keys() -> Array:
	var known: Array = []
	for key in PROVIDER_ORDER_HINT:
		if _providers.has(key):
			known.append(key)
	for key in _providers.keys():
		if not known.has(key):
			known.append(key)
	return known


## Upgrades an old payload to the current format. Empty for now; every future
## format change adds one step here so old saves keep loading.
func _migrate(payload: Dictionary, _from_version: int) -> Dictionary:
	return payload
