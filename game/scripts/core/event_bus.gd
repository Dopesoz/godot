extends Node

## Autoload: EventBus
##
## The only global signal hub. Systems never hold references to each other; they
## emit here and listen here. This is what keeps the model layer (WorldGrid,
## Citizen simulation) free of any knowledge about scenes, sprites and UI.
##
## Rules for adding a signal:
##   1. Past tense — it reports something that already happened, it is not a command.
##   2. Payload is plain data or model objects, never nodes.
##   3. Group it under the right heading and document the arguments.
##
## Commands go the other way: UI calls a controller method directly. The bus is
## one-directional (model -> everyone), which keeps it debuggable.


# --- World ------------------------------------------------------------------

## A fresh world model was built and is ready to be visualised.
signal world_ready(world)
## Terrain or occupancy of a single cell changed.
signal cell_changed(cell: Vector2i, floor_index: int)
## A wall/door/window edge changed. `edge` is a canonical Vector3i key.
signal edge_changed(edge: Vector3i, floor_index: int)


# --- Building ---------------------------------------------------------------

signal building_placed(building)
signal building_removed(building_id: int)
## Room detection ran and produced a different set of rooms for this building.
signal rooms_rebuilt(building_id: int, rooms: Array)
signal room_type_changed(room_id: int, room_type: int)
signal furniture_placed(furniture)
signal furniture_removed(furniture_id: int)


# --- Build mode -------------------------------------------------------------

signal tool_mode_changed(mode: int)
## Emitted when the player tries something the rules forbid, so the UI can show
## a reason instead of silently doing nothing.
signal build_rejected(reason: String)


# --- View -------------------------------------------------------------------

## Player entered or left the interior view of a building (design doc §11).
## `building_id` is -1 when leaving.
signal view_mode_changed(mode: int, building_id: int)
signal selection_changed(selected)


# --- Time -------------------------------------------------------------------

signal minute_passed(hour: int, minute: int)
signal hour_passed(hour: int)
signal day_passed(day: int)
## Normalised 0..1 daylight, emitted whenever it moves enough to matter.
signal daylight_changed(amount: float)
signal time_speed_changed(speed_index: int)


# --- Citizens ---------------------------------------------------------------

signal citizen_spawned(citizen)
signal citizen_removed(citizen_id: int)
signal citizen_state_changed(citizen_id: int, state: int)
## A need crossed below GameConstants.NEED_URGENT_THRESHOLD.
signal citizen_need_critical(citizen_id: int, need: int, value: float)
signal citizen_interaction_started(citizen_id: int, furniture_id: int, action: String)
signal citizen_interaction_finished(citizen_id: int, furniture_id: int, action: String)
signal relationship_changed(citizen_a: int, citizen_b: int, value: float)


# --- Economy ----------------------------------------------------------------

signal money_changed(amount: int, delta: int)
signal transaction_rejected(cost: int, reason: String)


# --- Persistence ------------------------------------------------------------

signal save_started(slot: String)
signal save_finished(slot: String, success: bool)
signal load_started(slot: String)
signal load_finished(slot: String, success: bool)


# --- Debug ------------------------------------------------------------------

## Human-readable notice for the on-screen log. Never used for game logic.
signal notice(text: String)


func notify(text: String) -> void:
	notice.emit(text)
	if OS.is_debug_build():
		print("[notice] ", text)
